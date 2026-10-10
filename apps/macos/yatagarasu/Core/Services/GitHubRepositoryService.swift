//
//  GitHubRepositoryService.swift
//  yatagarasu
//
//  Created by Copilot on 3/9/26.
//

import Foundation

enum GitHubRepositoryServiceError: LocalizedError {
    case invalidEndpoint(owner: String, repository: String)
    case invalidResponse
    case requestFailed(url: URL, statusCode: Int, message: String)
    case unsupportedReadmeEncoding(String?)

    var errorDescription: String? {
        switch self {
        case let .invalidEndpoint(owner, repository):
            return "Could not build a valid GitHub API endpoint for \(owner)/\(repository)."
        case .invalidResponse:
            return "GitHub returned an invalid response."
        case let .requestFailed(url, statusCode, message):
            if message.isEmpty {
                return "GitHub request failed (\(statusCode)) for \(url.absoluteString)."
            }
            return "GitHub request failed (\(statusCode)) for \(url.absoluteString): \(message)"
        case let .unsupportedReadmeEncoding(encoding):
            return "GitHub returned README content with an unsupported encoding: \(encoding ?? "unknown")."
        }
    }

    var isNotFound: Bool {
        switch self {
        case let .requestFailed(_, statusCode, _):
            return statusCode == 404
        default:
            return false
        }
    }
}

struct GitHubRepositorySnapshot: Sendable {
    let owner: String
    let name: String
    let fullName: String
    let summaryText: String
    let repositoryURLString: String
    let homepageURLString: String?
    let primaryLanguage: String?
    let stargazerCount: Int
    let defaultBranch: String
    let readme: GitHubReadmeSnapshot?
    let releases: [GitHubReleaseSnapshot]
}

struct GitHubReadmeSnapshot: Sendable {
    let markdownContent: String
    let excerpt: String
}

struct GitHubReleaseSnapshot: Sendable {
    let name: String
    let tagName: String
    let notesSummary: String
    let publishedAt: Date
    let isDraft: Bool
    let isPrerelease: Bool
    let assetCount: Int
    let hasInstallableAsset: Bool
    let releaseURLString: String
    let preferredInstallAssetName: String?
    let preferredInstallAssetDownloadURLString: String?
    let preferredInstallAssetKindRawValue: String?
    let preferredInstallAssetArchitectureRawValue: String?
}

struct GitHubRepositoryService: Sendable {
    func fetchCatalogEntry(
        owner: String,
        repositoryName: String
    ) async throws -> GitHubRepositorySnapshot {
        async let repository = fetchRepository(owner: owner, repositoryName: repositoryName)
        async let readme = fetchReadme(owner: owner, repositoryName: repositoryName)
        async let releases = fetchReleases(owner: owner, repositoryName: repositoryName)

        let repositoryPayload = try await repository
        let readmePayload = try await readme
        let releasesPayload = try await releases

        return GitHubRepositorySnapshot(
            owner: repositoryPayload.owner.login,
            name: repositoryPayload.name,
            fullName: repositoryPayload.fullName,
            summaryText: repositoryPayload.description?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "",
            repositoryURLString: repositoryPayload.htmlUrl,
            homepageURLString: repositoryPayload.homepage?.nonEmptyTrimmed,
            primaryLanguage: repositoryPayload.language?.nonEmptyTrimmed,
            stargazerCount: repositoryPayload.stargazersCount,
            defaultBranch: repositoryPayload.defaultBranch,
            readme: readmePayload,
            releases: releasesPayload
        )
    }

    private func fetchRepository(
        owner: String,
        repositoryName: String
    ) async throws -> GitHubRepositoryPayload {
        let endpoint = try makeEndpoint(
            owner: owner,
            repositoryName: repositoryName,
            path: ""
        )

        return try await requestJSON(
            GitHubRepositoryPayload.self,
            url: endpoint
        )
    }

    private func fetchReadme(
        owner: String,
        repositoryName: String
    ) async throws -> GitHubReadmeSnapshot? {
        do {
            let endpoint = try makeEndpoint(
                owner: owner,
                repositoryName: repositoryName,
                path: "/readme"
            )
            let payload = try await requestJSON(
                GitHubReadmePayload.self,
                url: endpoint
            )

            guard
                let encoding = payload.encoding?.lowercased(),
                encoding == "base64"
            else {
                throw GitHubRepositoryServiceError.unsupportedReadmeEncoding(payload.encoding)
            }

            guard
                let content = payload.content?
                    .replacingOccurrences(of: "\n", with: "")
                    .replacingOccurrences(of: "\r", with: ""),
                let decodedData = Data(base64Encoded: content),
                let markdown = String(data: decodedData, encoding: .utf8)?
                    .trimmingCharacters(in: .whitespacesAndNewlines),
                !markdown.isEmpty
            else {
                return nil
            }

            let resolvedMarkdown = rewriteRelativeImageSources(
                in: markdown,
                readmePath: payload.path,
                readmeDownloadURLString: payload.downloadUrl
            )

            return GitHubReadmeSnapshot(
                markdownContent: resolvedMarkdown,
                excerpt: summarize(markdown: resolvedMarkdown, limit: 260)
            )
        } catch let error as GitHubRepositoryServiceError where error.isNotFound {
            return nil
        }
    }

    private func fetchReleases(
        owner: String,
        repositoryName: String
    ) async throws -> [GitHubReleaseSnapshot] {
        let endpoint = try makeEndpoint(
            owner: owner,
            repositoryName: repositoryName,
            path: "/releases",
            queryItems: [
                URLQueryItem(name: "per_page", value: "12"),
            ]
        )

        let payload = try await requestJSON(
            [GitHubReleasePayload].self,
            url: endpoint
        )

        return payload.map { release in
            let preferredInstallAsset = preferredInstallAsset(from: release.assets)
            return GitHubReleaseSnapshot(
                name: release.name?.nonEmptyTrimmed ?? release.tagName,
                tagName: release.tagName,
                notesSummary: summarize(markdown: release.body ?? "", limit: 200),
                publishedAt: release.publishedAt ?? release.createdAt ?? .distantPast,
                isDraft: release.draft,
                isPrerelease: release.prerelease,
                assetCount: release.assets.count,
                hasInstallableAsset: preferredInstallAsset != nil,
                releaseURLString: release.htmlUrl,
                preferredInstallAssetName: preferredInstallAsset?.name,
                preferredInstallAssetDownloadURLString: preferredInstallAsset?.downloadURLString,
                preferredInstallAssetKindRawValue: preferredInstallAsset?.kind.rawValue,
                preferredInstallAssetArchitectureRawValue: preferredInstallAsset?.architecture.rawValue
            )
        }
    }

    private func requestJSON<T: Decodable>(
        _ type: T.Type,
        url: URL
    ) async throws -> T {
        let data = try await requestData(url: url)
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(type, from: data)
    }

    private func requestData(url: URL) async throws -> Data {
        var request = URLRequest(url: url)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("Yatagarasu", forHTTPHeaderField: "User-Agent")
        request.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw GitHubRepositoryServiceError.invalidResponse
        }

        guard (200 ... 299).contains(httpResponse.statusCode) else {
            let bodyText = String(data: data, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            throw GitHubRepositoryServiceError.requestFailed(
                url: url,
                statusCode: httpResponse.statusCode,
                message: bodyText
            )
        }

        return data
    }

    private func makeEndpoint(
        owner: String,
        repositoryName: String,
        path: String,
        queryItems: [URLQueryItem] = []
    ) throws -> URL {
        var components = URLComponents()
        components.scheme = "https"
        components.host = "api.github.com"
        components.path = "/repos/\(owner)/\(repositoryName)\(path)"
        components.queryItems = queryItems.isEmpty ? nil : queryItems

        guard let url = components.url else {
            throw GitHubRepositoryServiceError.invalidEndpoint(
                owner: owner,
                repository: repositoryName
            )
        }

        return url
    }

    private func rewriteRelativeImageSources(
        in markdown: String,
        readmePath: String?,
        readmeDownloadURLString: String?
    ) -> String {
        guard
            let readmePath = readmePath?.nonEmptyTrimmed,
            let readmeDownloadURLString = readmeDownloadURLString,
            let readmeDownloadURL = URL(string: readmeDownloadURLString)
        else {
            return markdown
        }

        let readmeDirectoryURL = readmeDownloadURL.deletingLastPathComponent()
        let repositoryRootURL = repositoryRootURL(
            from: readmeDownloadURL,
            readmePath: readmePath
        )

        let markdownResolved = rewriteMatches(
            in: markdown,
            pattern: #"\!\[[^\]]*\]\(\s*<?([^)\s>]+)>?(?:\s+["'][^"']*["'])?\s*\)"#,
            captureGroupIndex: 1
        ) { source in
            resolveImageURL(
                source,
                readmeDirectoryURL: readmeDirectoryURL,
                repositoryRootURL: repositoryRootURL
            )
        }

        return rewriteMatches(
            in: markdownResolved,
            pattern: #"(?i)<img\b[^>]*\bsrc\s*=\s*(['"])(.*?)\1[^>]*>"#,
            captureGroupIndex: 2
        ) { source in
            resolveImageURL(
                source,
                readmeDirectoryURL: readmeDirectoryURL,
                repositoryRootURL: repositoryRootURL
            )
        }
    }

    private func repositoryRootURL(
        from readmeDownloadURL: URL,
        readmePath: String
    ) -> URL {
        var repositoryRootURL = readmeDownloadURL
        for _ in readmePath.split(separator: "/") {
            repositoryRootURL.deleteLastPathComponent()
        }
        return repositoryRootURL
    }

    private func resolveImageURL(
        _ source: String,
        readmeDirectoryURL: URL,
        repositoryRootURL: URL
    ) -> String? {
        let trimmedSource = source.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedSource.isEmpty else {
            return nil
        }

        let unwrappedSource = unwrapAngleBrackets(in: trimmedSource)

        if hasAbsoluteScheme(unwrappedSource) || unwrappedSource.hasPrefix("#") {
            return nil
        }

        let baseURL = unwrappedSource.hasPrefix("/") ? repositoryRootURL : readmeDirectoryURL
        let relativePath = unwrappedSource.hasPrefix("/")
            ? String(unwrappedSource.dropFirst())
            : unwrappedSource

        guard
            let resolvedURL = URL(string: relativePath, relativeTo: baseURL)?
                .absoluteURL
        else {
            return nil
        }

        return resolvedURL.absoluteString
    }

    private func rewriteMatches(
        in text: String,
        pattern: String,
        captureGroupIndex: Int,
        transform: (String) -> String?
    ) -> String {
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return text
        }

        let fullRange = NSRange(text.startIndex..., in: text)
        let matches = regex.matches(in: text, range: fullRange)
        guard !matches.isEmpty else {
            return text
        }

        var rewritten = text
        for match in matches.reversed() {
            guard
                let range = Range(match.range(at: captureGroupIndex), in: rewritten)
            else {
                continue
            }

            let source = String(rewritten[range])
            guard let replacement = transform(source) else {
                continue
            }

            rewritten.replaceSubrange(range, with: replacement)
        }

        return rewritten
    }

    private func unwrapAngleBrackets(in value: String) -> String {
        guard value.hasPrefix("<"), value.hasSuffix(">"), value.count >= 2 else {
            return value
        }
        return String(value.dropFirst().dropLast())
    }

    private func hasAbsoluteScheme(_ value: String) -> Bool {
        guard let schemeRange = value.range(of: ":") else {
            return false
        }

        let scheme = value[..<schemeRange.lowerBound]
        return !scheme.isEmpty && scheme.allSatisfy { character in
            character.isLetter || character.isNumber || character == "+" || character == "-" || character == "."
        }
    }

    private func preferredInstallAsset(
        from assets: [GitHubReleaseAssetPayload]
    ) -> GitHubInstallAssetCandidate? {
        assets
            .compactMap(makeInstallCandidate(from:))
            .sorted(by: isPreferredCandidate(_:_:))
            .first
    }

    private func makeInstallCandidate(
        from asset: GitHubReleaseAssetPayload
    ) -> GitHubInstallAssetCandidate? {
        let normalizedName = asset.name.lowercased()
        guard let kind = assetKind(from: normalizedName) else {
            return nil
        }

        if containsAnyToken(in: normalizedName, tokens: nonMacPlatformTokens),
           !containsAnyToken(in: normalizedName, tokens: macPlatformTokens) {
            return nil
        }

        let architecture = assetArchitecture(from: normalizedName)
        guard architecture.isCompatible(with: currentArchitecture) else {
            return nil
        }

        return GitHubInstallAssetCandidate(
            name: asset.name,
            downloadURLString: asset.browserDownloadUrl,
            kind: kind,
            architecture: architecture,
            mentionsMacPlatform: containsAnyToken(in: normalizedName, tokens: macPlatformTokens)
        )
    }

    private func isPreferredCandidate(
        _ lhs: GitHubInstallAssetCandidate,
        _ rhs: GitHubInstallAssetCandidate
    ) -> Bool {
        if lhs.kind.preferenceRank != rhs.kind.preferenceRank {
            return lhs.kind.preferenceRank < rhs.kind.preferenceRank
        }

        if lhs.architecture.preferenceRank(for: currentArchitecture) != rhs.architecture.preferenceRank(for: currentArchitecture) {
            return lhs.architecture.preferenceRank(for: currentArchitecture) < rhs.architecture.preferenceRank(for: currentArchitecture)
        }

        if lhs.mentionsMacPlatform != rhs.mentionsMacPlatform {
            return lhs.mentionsMacPlatform && !rhs.mentionsMacPlatform
        }

        return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
    }

    private func assetKind(from normalizedName: String) -> GitHubReleaseAssetKind? {
        if normalizedName.hasSuffix(".dmg") {
            return .dmg
        }
        if normalizedName.hasSuffix(".pkg") {
            return .pkg
        }
        if normalizedName.hasSuffix(".zip") {
            return .zip
        }
        return nil
    }

    private func assetArchitecture(from normalizedName: String) -> GitHubReleaseAssetArchitecture {
        if containsAnyToken(in: normalizedName, tokens: ["universal", "all"]) {
            return .universal
        }
        if containsAnyToken(in: normalizedName, tokens: ["arm64", "aarch64", "apple-silicon"]) {
            return .appleSilicon
        }
        if containsAnyToken(in: normalizedName, tokens: ["x86_64", "amd64", "intel"]) {
            return .intel
        }
        return .generic
    }

    private func containsAnyToken(in normalizedName: String, tokens: [String]) -> Bool {
        tokens.contains { normalizedName.contains($0) }
    }

    private var currentArchitecture: CurrentMacArchitecture {
        #if arch(arm64)
        .appleSilicon
        #elseif arch(x86_64)
        .intel
        #else
        .intel
        #endif
    }

    private var macPlatformTokens: [String] {
        ["macos", "mac", "darwin", "osx", "apple"]
    }

    private var nonMacPlatformTokens: [String] {
        [
            "windows",
            ".msi",
            ".exe",
            "linux",
            "ubuntu",
            ".deb",
            ".rpm",
            "appimage",
            "flatpak",
            "android",
            "ios",
        ]
    }

    private func summarize(markdown: String, limit: Int) -> String {
        let cleaned = markdown
            .components(separatedBy: .newlines)
            .map { line in
                line
                    .replacingOccurrences(of: "#", with: "")
                    .replacingOccurrences(of: "`", with: "")
                    .replacingOccurrences(of: "*", with: "")
                    .replacingOccurrences(of: ">", with: "")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
            }
            .filter { !$0.isEmpty }
            .joined(separator: " ")

        guard cleaned.count > limit else {
            return cleaned
        }

        let prefix = String(cleaned.prefix(limit)).trimmingCharacters(in: .whitespacesAndNewlines)
        return prefix + "..."
    }
}

private struct GitHubRepositoryPayload: Decodable {
    struct OwnerPayload: Decodable {
        let login: String
    }

    let owner: OwnerPayload
    let name: String
    let fullName: String
    let description: String?
    let htmlUrl: String
    let homepage: String?
    let language: String?
    let stargazersCount: Int
    let defaultBranch: String
}

private struct GitHubReadmePayload: Decodable {
    let content: String?
    let encoding: String?
    let path: String?
    let downloadUrl: String?
}

private struct GitHubReleasePayload: Decodable {
    let name: String?
    let tagName: String
    let htmlUrl: String
    let body: String?
    let publishedAt: Date?
    let createdAt: Date?
    let draft: Bool
    let prerelease: Bool
    let assets: [GitHubReleaseAssetPayload]
}

private struct GitHubReleaseAssetPayload: Decodable {
    let name: String
    let browserDownloadUrl: String
}

private enum CurrentMacArchitecture {
    case appleSilicon
    case intel
}

private struct GitHubInstallAssetCandidate: Sendable {
    let name: String
    let downloadURLString: String
    let kind: GitHubReleaseAssetKind
    let architecture: GitHubReleaseAssetArchitecture
    let mentionsMacPlatform: Bool
}

private extension GitHubReleaseAssetKind {
    var preferenceRank: Int {
        switch self {
        case .dmg:
            0
        case .pkg:
            1
        case .zip:
            2
        }
    }
}

private extension GitHubReleaseAssetArchitecture {
    func isCompatible(with currentArchitecture: CurrentMacArchitecture) -> Bool {
        switch (self, currentArchitecture) {
        case (.appleSilicon, .intel), (.intel, .appleSilicon):
            false
        default:
            true
        }
    }

    func preferenceRank(for currentArchitecture: CurrentMacArchitecture) -> Int {
        switch (self, currentArchitecture) {
        case (.appleSilicon, .appleSilicon), (.intel, .intel):
            0
        case (.universal, _):
            1
        case (.generic, _):
            2
        case (.appleSilicon, .intel), (.intel, .appleSilicon):
            3
        }
    }
}

private extension String {
    var nonEmptyTrimmed: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
