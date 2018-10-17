import Foundation
import HSEthereumKit
import RealmSwift
import RxSwift

class EthereumAdapter {
    private let ethereumKit: EthereumKit
    private let transactionCompletionThreshold = 12
    private let coinRate: Double = pow(10, 18)

    let wordsHash: String
    let coin: Coin
    let balanceSubject = PublishSubject<Double>()
    let progressSubject: BehaviorSubject<Double>
    let lastBlockHeightSubject = PublishSubject<Int>()
    let transactionRecordsSubject = PublishSubject<Void>()

    init(words: [String], network: Network) {
        wordsHash = words.joined()

        switch network {
        case .mainnet: coin = Ethereum()
        case .kovan: coin = Ethereum(prefix: "k")
        case .ropsten: coin = Ethereum(prefix: "r")
        case .private: coin = Ethereum(prefix: "pr")
        }

        progressSubject = BehaviorSubject(value: 1)

        ethereumKit = EthereumKit(withWords: words, network: network, debugPrints: true)
        ethereumKit.delegate = self
    }

    private func transactionRecord(fromTransaction transaction: EthereumTransaction) -> TransactionRecord {
        let status: TransactionStatus

        if transaction.confirmations == 0 {
            status = .processing
        } else if transaction.confirmations >= transactionCompletionThreshold {
            status = .completed
        } else {
            status = .verifying(progress: Double(transaction.confirmations) / Double(transactionCompletionThreshold))
        }
        let amountEther = convertToValue(amount: transaction.value) ?? 0

        let mineAddress = ethereumKit.receiveAddress.lowercased()
        let from = TransactionAddress(address: transaction.from, mine: transaction.from.lowercased() == mineAddress)
        let to = TransactionAddress(address: transaction.to, mine: transaction.to.lowercased() == mineAddress)
        return TransactionRecord(
                transactionHash: transaction.txHash,
                from: [from],
                to: [to],
                amount: amountEther * (from.mine ? -1 : 1),
                status: status,
                timestamp: transaction.timestamp
        )
    }

    private func convertToValue(amount: String) -> Double? {
        if let result = Decimal(string: amount) {
            return Double(truncating: (result / pow(10, 18)) as NSNumber)
        }
        return nil
    }

}

extension EthereumAdapter: IAdapter {

    var id: String {
        return "\(wordsHash)-\(coin.code)"
    }

    var balance: Double {
        return Double(ethereumKit.balance) / coinRate
    }

    var lastBlockHeight: Int {
        return 0
    }

    var transactionRecords: [TransactionRecord] {
        return ethereumKit.transactions.map { transactionRecord(fromTransaction: $0) }
    }

    func showInfo() {
        ethereumKit.showRealmInfo()
    }

    func start() {
        ethereumKit.start()
    }

    func refresh() {
        ethereumKit.refresh()
    }

    func clear() {
        try? ethereumKit.clear()
    }

    func send(to address: String, value: Double, completion: ((Error?) -> ())?) {
        ethereumKit.send(to: address, value: Decimal(value), completion: completion)
    }

    func fee(for value: Double, senderPay: Bool) throws -> Double {
        return Double(ethereumKit.fee) / coinRate
    }

    func validate(address: String) throws {
        try ethereumKit.validate(address: address)
    }

    var receiveAddress: String {
        return ethereumKit.receiveAddress
    }

}

extension EthereumAdapter: EthereumKitDelegate {

    public func transactionsUpdated(walletKit: EthereumKit, inserted: [EthereumTransaction], updated: [EthereumTransaction], deleted: [Int]) {
        transactionRecordsSubject.onNext(())
    }

    public func balanceUpdated(walletKit: EthereumKit, balance: BInt) {
        balanceSubject.onNext(Double(balance) / coinRate)
    }

}