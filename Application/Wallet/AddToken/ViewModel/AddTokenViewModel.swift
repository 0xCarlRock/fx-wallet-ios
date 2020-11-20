import RxCocoa
import RxSwift
import WKKit
extension AddTokenViewController {
    class ViewModel {
        init(_ wallet: WKWallet) {
            listViewModel = ListViewModel(wallet)
            searchListViewModel = AddCoinListViewModel(wallet, hideAddedItem: false)
        }

        let listViewModel: ListViewModel
        let searchListViewModel: AddCoinListViewModel
    }
}

extension AddTokenViewController {
    class ListViewModel {
        init(_ wallet: WKWallet) {
            self.wallet = wallet
            loadCoins()
        }

        let wallet: WKWallet
        var items: [[AddCoinCellViewModel]] = []
        private func loadCoins() {
            let current = wallet.coins
            var suggest: [AddCoinCellViewModel] = []
            for coin in CoinService.current.defaultItems {
                let item = AddCoinCellViewModel(coin)
                suggest.append(item)
                item.isAdded = current.first(where: { $0.id == coin.id }) != nil
            }
            var available: [AddCoinCellViewModel] = []
            for coin in CoinService.current.coins {
                let item = AddCoinCellViewModel(coin)
                available.append(item)
                item.isAdded = current.first(where: { $0.id == coin.id }) != nil
            }
            suggest.last?.corners = (false, true)
            available.last?.corners = (false, true)
            items = [suggest, available]
        }
    }
}
