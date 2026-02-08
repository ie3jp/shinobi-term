import StoreKit

@MainActor
final class TipJarService: ObservableObject {
    static let beerTipID = "com.rettuce.shinobiterm.tip.beer"

    @Published private(set) var beerProduct: Product?
    @Published private(set) var purchaseState: PurchaseState = .idle

    enum PurchaseState: Equatable {
        case idle
        case purchasing
        case success
        case failed(String)
    }

    init() {
        Task { await loadProducts() }
    }

    func loadProducts() async {
        do {
            let products = try await Product.products(for: [Self.beerTipID])
            beerProduct = products.first
        } catch {
            beerProduct = nil
        }
    }

    func purchaseBeer() async {
        guard let product = beerProduct else { return }

        purchaseState = .purchasing
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                await transaction.finish()
                purchaseState = .success
            case .userCancelled:
                purchaseState = .idle
            case .pending:
                purchaseState = .idle
            @unknown default:
                purchaseState = .idle
            }
        } catch {
            purchaseState = .failed(error.localizedDescription)
        }
    }

    func resetState() {
        purchaseState = .idle
    }

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified(_, let error):
            throw error
        case .verified(let value):
            return value
        }
    }
}
