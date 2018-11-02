import RxSwift

class TransactionManager {
    private let disposeBag = DisposeBag()
    private var adaptersDisposeBag = DisposeBag()

    private let walletManager: IWalletManager
    private let realmFactory: IRealmFactory
    private let rateManager: IRateManager

    init(walletManager: IWalletManager, realmFactory: IRealmFactory, rateManager: IRateManager) {
        self.walletManager = walletManager
        self.realmFactory = realmFactory
        self.rateManager = rateManager

        resubscribeToAdapters()

        walletManager.walletsSubject
                .subscribe(onNext: { [weak self] _ in
                    self?.resubscribeToAdapters()
                })
                .disposed(by: disposeBag)
    }

    private func resubscribeToAdapters() {
        adaptersDisposeBag = DisposeBag()

        walletManager.wallets.forEach { wallet in
            wallet.adapter.transactionRecordsSubject
                    .subscribe(onNext: { [weak self] records in
                        self?.handle(records: records, forCoin: wallet.coin)
                    })
                    .disposed(by: adaptersDisposeBag)
        }
    }

    private func handle(records: [TransactionRecord], forCoin coin: Coin) {
        records.forEach { record in
            record.coin = coin
        }

        let realm = realmFactory.realm

        try? realm.write {
            realm.add(records, update: true)
        }

        rateManager.fillTransactionRates()
    }

}

extension TransactionManager: ITransactionManager {

    func clear() {
        let realm = realmFactory.realm

        try? realm.write {
            realm.delete(realm.objects(TransactionRecord.self))
        }
    }

}