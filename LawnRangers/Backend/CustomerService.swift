import Foundation

/// A customer row from the "Customers" tab (Standard Rate + Address).
struct CustomerInfo: Decodable {
    let customer: String
    let rate: Double?
    let address: String?
}

private struct CustomersResponse: Decodable {
    let customers: [CustomerInfo]
    let error: String?
}

/// Reads the customer directory (Customers tab) from the Apps Script Web App.
enum CustomerService {
    static func fetch() async throws -> [CustomerInfo] {
        guard let base = BackendConfig.webAppURL else {
            throw NSError(domain: "Customers", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "No backend URL configured (Settings)."])
        }
        var comps = URLComponents(url: base, resolvingAgainstBaseURL: false)
        comps?.queryItems = [URLQueryItem(name: "action", value: "customers")]
        guard let url = comps?.url else { throw URLError(.badURL) }

        let (data, response) = try await URLSession.shared.data(from: url)
        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode(CustomersResponse.self, from: data).customers
    }
}
