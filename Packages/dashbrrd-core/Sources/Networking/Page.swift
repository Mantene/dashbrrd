import Foundation

/// A single page of a Servarr paged collection (`page`/`pageSize`/`totalRecords`/`records`).
public struct Page<Element: Sendable>: Sendable {
    public var page: Int
    public var pageSize: Int
    public var totalRecords: Int
    public var records: [Element]

    public init(page: Int, pageSize: Int, totalRecords: Int, records: [Element]) {
        self.page = page
        self.pageSize = pageSize
        self.totalRecords = totalRecords
        self.records = records
    }

    /// Whether more pages exist beyond this one.
    public var hasMore: Bool { page * pageSize < totalRecords }
}

extension Page: Equatable where Element: Equatable {}

/// Parameters for a paged request.
public struct PagedRequest: Sendable, Hashable {
    public enum SortDirection: String, Sendable {
        case ascending
        case descending
    }

    public var page: Int
    public var pageSize: Int
    public var sortKey: String?
    public var sortDirection: SortDirection?

    public init(
        page: Int = 1,
        pageSize: Int = 50,
        sortKey: String? = nil,
        sortDirection: SortDirection? = nil
    ) {
        self.page = page
        self.pageSize = pageSize
        self.sortKey = sortKey
        self.sortDirection = sortDirection
    }
}
