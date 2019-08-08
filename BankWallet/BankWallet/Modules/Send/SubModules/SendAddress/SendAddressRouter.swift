import UIKit

class SendAddressRouter {

    static func module(addressParser: IAddressParser, canEdit: Bool = false, placeholder: String = "send.address_placeholder") -> (UIView, ISendAddressModule) {
        let interactor = SendAddressInteractor(pasteboardManager: App.shared.pasteboardManager, addressParser: addressParser)

        let presenter = SendAddressPresenter(interactor: interactor)
        let view = SendAddressView(canEdit: canEdit, placeholder: placeholder, delegate: presenter)

        presenter.view = view

        return (view, presenter)
    }

}