import MapKit
import UIKit

final class CarPlayMapViewController: UIViewController {
  private let mapView = MKMapView()
  private let titleLabel = UILabel()
  private let subtitleLabel = UILabel()
  private let statusLabel = UILabel()

  override func viewDidLoad() {
    super.viewDidLoad()

    view.backgroundColor = .black
    configureMapView()
    configureOverlay()
  }

  private func configureMapView() {
    mapView.translatesAutoresizingMaskIntoConstraints = false
    mapView.showsCompass = false
    mapView.showsScale = false
    mapView.pointOfInterestFilter = .excludingAll
    mapView.overrideUserInterfaceStyle = .dark

    let region = MKCoordinateRegion(
      center: CLLocationCoordinate2D(latitude: 59.3293, longitude: 18.0686),
      span: MKCoordinateSpan(latitudeDelta: 0.12, longitudeDelta: 0.12)
    )
    mapView.setRegion(region, animated: false)

    view.addSubview(mapView)

    NSLayoutConstraint.activate([
      mapView.topAnchor.constraint(equalTo: view.topAnchor),
      mapView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
      mapView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
      mapView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
    ])
  }

  private func configureOverlay() {
    let overlay = UIVisualEffectView(effect: UIBlurEffect(style: .systemChromeMaterialDark))
    overlay.translatesAutoresizingMaskIntoConstraints = false
    overlay.layer.cornerRadius = 18
    overlay.clipsToBounds = true

    titleLabel.translatesAutoresizingMaskIntoConstraints = false
    titleLabel.text = "CruizX CarPlay"
    titleLabel.textColor = .white
    titleLabel.font = .preferredFont(forTextStyle: .title2)

    subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
    subtitleLabel.text = "Synkar sparade och senaste mål från appen."
    subtitleLabel.textColor = UIColor.white.withAlphaComponent(0.82)
    subtitleLabel.font = .preferredFont(forTextStyle: .subheadline)
    subtitleLabel.numberOfLines = 0

    statusLabel.translatesAutoresizingMaskIntoConstraints = false
    statusLabel.text = "Väntar på data från appen."
    statusLabel.textColor = UIColor(red: 0.76, green: 0.88, blue: 1.0, alpha: 1)
    statusLabel.font = .preferredFont(forTextStyle: .footnote)
    statusLabel.numberOfLines = 0

    overlay.contentView.addSubview(titleLabel)
    overlay.contentView.addSubview(subtitleLabel)
    overlay.contentView.addSubview(statusLabel)
    view.addSubview(overlay)

    NSLayoutConstraint.activate([
      overlay.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
      overlay.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
      overlay.widthAnchor.constraint(lessThanOrEqualToConstant: 420),

      titleLabel.topAnchor.constraint(equalTo: overlay.contentView.topAnchor, constant: 16),
      titleLabel.leadingAnchor.constraint(equalTo: overlay.contentView.leadingAnchor, constant: 18),
      titleLabel.trailingAnchor.constraint(equalTo: overlay.contentView.trailingAnchor, constant: -18),

      subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
      subtitleLabel.leadingAnchor.constraint(equalTo: overlay.contentView.leadingAnchor, constant: 18),
      subtitleLabel.trailingAnchor.constraint(equalTo: overlay.contentView.trailingAnchor, constant: -18),

      statusLabel.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: 10),
      statusLabel.leadingAnchor.constraint(equalTo: overlay.contentView.leadingAnchor, constant: 18),
      statusLabel.trailingAnchor.constraint(equalTo: overlay.contentView.trailingAnchor, constant: -18),
      statusLabel.bottomAnchor.constraint(equalTo: overlay.contentView.bottomAnchor, constant: -16),
    ])
  }

  func updateOverlay(title: String, subtitle: String, status: String) {
    guard isViewLoaded else { return }
    titleLabel.text = title
    subtitleLabel.text = subtitle
    statusLabel.text = status
  }
}
