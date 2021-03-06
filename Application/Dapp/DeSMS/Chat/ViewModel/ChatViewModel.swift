import FunctionX
import RxCocoa
import RxSwift
import WKKit
extension ChatViewController {
    class ViewModel: WKListViewModel<CellViewModel> {
        let service: SmsMessageService
        var wallet: FxWallet { service.wallet }
        var address: String { wallet.address }
        private(set) var needReload = PublishSubject<Bool>()
        lazy var firstLoadFinished = BehaviorRelay<Bool>(value: false)
        lazy var lastUpdateDate = BehaviorRelay<String>(value: TR("Chat.LastUpdate$", "--"))
        deinit { self.service.offline() }
        init(receiver: SmsUser, wallet: FxWallet) {
            service = SmsServiceManager.service(forWallet: wallet, receiver: receiver)
            super.init()
            setupList()
            bindService()
        }

        private func setupList() {
            pager.page = 0
            pager.pageSize = 20
            service.pageSize = pager.pageSize
            refreshItems = Action { [weak self] _ -> Observable<[CellViewModel]> in
                guard let this = self else { return Observable.empty() }
                return this.service.loadLatest(this.pager.page)
                    .observeOn(MainScheduler.instance)
                    .do(onNext: { items in
                        this.handle(items)
                        this.pager.page = items.count + this.pager.pageSize
                        this.fetchLastUpdateDate()
                        if !this.firstLoadFinished.value {
                            this.firstLoadFinished.accept(items.count > 0)
                        }
                    })
            }
            service.preload()
                .filter { $0.isNotEmpty }
                .observeOn(MainScheduler.instance)
                .subscribe(onNext: { [weak self] items in
                    self?.handle(items)
                    self?.needReload.onNext(true)
                    self?.firstLoadFinished.accept(true)
                }).disposed(by: defaultBag)
        }

        private func bindService() {
            service.didUpdate.subscribe(onNext: { [weak self] updateMsgs in
                guard let this = self else { return }
                let (new, del) = updateMsgs
                if let delItems = del, delItems.isNotEmpty {
                    for item in delItems {
                        if let idx = this.items.lastIndexOf(condition: { $0.rawValue.sendingHeight == item.rawValue.sendingHeight }) {
                            this.items.remove(at: idx)
                        }
                    }
                }
                if let newItems = new, newItems.isNotEmpty {
                    this.items.append(contentsOf: newItems)
                }
                this.needReload.onNext(true)
                this.fetchLastUpdateDate()
            }).disposed(by: defaultBag)
        }

        private func fetchLastUpdateDate() {
            if let sms = items.last {
                lastUpdateDate.accept(TR("Chat.LastUpdate$", sms.rawValue.availableTime))
            }
        }

        private func handle(_ items: [CellViewModel]) {
            guard items.isNotEmpty else { return }
            var compareItem = items.first!
            if compareItem.isToday {
                self.items = items
            } else {
                var temp: [CellViewModel] = [DateCellViewModel(compareItem.rawValue)]
                for item in items {
                    if !compareItem.isToday, !compareItem.date.isSameDay(date: item.date) {
                        temp.append(DateCellViewModel(item.rawValue))
                        compareItem = item
                    }
                    temp.append(item)
                }
                self.items = temp
            }
        }
    }
}
