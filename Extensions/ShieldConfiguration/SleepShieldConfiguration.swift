import ManagedSettings
import ManagedSettingsUI
import UIKit

final class SleepShieldConfiguration: ShieldConfigurationDataSource {
    private var appearance: ShieldConfiguration {
        ShieldConfiguration(
            backgroundBlurStyle: .systemUltraThinMaterialDark,
            backgroundColor: UIColor(red: 0.047, green: 0.059, blue: 0.098, alpha: 1),
            icon: UIImage(systemName: "moon.stars"),
            title: .init(text: "The day can wait.", color: .white),
            subtitle: .init(
                text: "You made room for a quieter night. Leave this app here, or open Sleep App for your quiet activity and protection controls.",
                color: UIColor(red: 0.75, green: 0.77, blue: 0.84, alpha: 1)
            ),
            primaryButtonLabel: .init(text: "Leave this app", color: UIColor(red: 0.047, green: 0.059, blue: 0.098, alpha: 1)),
            primaryButtonBackgroundColor: UIColor(red: 0.773, green: 0.745, blue: 0.965, alpha: 1)
        )
    }
    override func configuration(shielding application: Application) -> ShieldConfiguration { appearance }
    override func configuration(shielding application: Application, in category: ActivityCategory) -> ShieldConfiguration { appearance }
    override func configuration(shielding webDomain: WebDomain) -> ShieldConfiguration { appearance }
    override func configuration(shielding webDomain: WebDomain, in category: ActivityCategory) -> ShieldConfiguration { appearance }
}
