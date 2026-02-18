import StoreKit

@MainActor
final class TipJarService: ObservableObject {
    static let beerTipID = "com.rettuce.shinobiterm.tip.beer"

    @Published private(set) var beerProduct: Product?
    @Published private(set) var purchaseState: PurchaseState = .idle
    @Published private(set) var productLoadError: String?

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
        productLoadError = nil
        do {
            let products = try await Product.products(for: [Self.beerTipID])
            beerProduct = products.first
            if beerProduct == nil {
                productLoadError = "product unavailable"
            }
        } catch {
            beerProduct = nil
            productLoadError = "failed to load: \(error.localizedDescription)"
        }
    }

    func purchaseBeer() async {
        if beerProduct == nil {
            await loadProducts()
        }
        guard let product = beerProduct else {
            purchaseState = .failed("Unable to load product. Please check your connection and try again.")
            return
        }

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
