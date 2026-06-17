// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get appTitle => 'CruizX';

  @override
  String get navMap => 'Mapa';

  @override
  String get navAlerts => 'Alertas';

  @override
  String get navConvoy => 'Convoy';

  @override
  String get navProfile => 'Perfil';

  @override
  String get navSettings => 'Ajustes';

  @override
  String get splashPreparingStartup => 'Preparando el inicio...';

  @override
  String get splashLoadingCoreModules => 'Cargando módulos principales...';

  @override
  String get splashInitializingAccountSession => 'Iniciando sesión de cuenta...';

  @override
  String get splashLoadingPreferences => 'Cargando preferencias...';

  @override
  String get splashFinalizingStartup => 'Finalizando inicio...';

  @override
  String get splashReady => 'Listo';

  @override
  String get splashVersionLine => 'v1.0.6 | CruizX by KimTechTool';

  @override
  String get alertsTitle => 'Alertas de la comunidad';

  @override
  String get alertsSubtitle => 'Reporta y consulta peligros, controles y condiciones de la vía.';

  @override
  String get convoyRequiresSignInTitle => 'El convoy requiere inicio de sesión';

  @override
  String get convoyRequiresSignInSubtitle => 'Inicia sesión o crea una cuenta para crear grupos de convoy y ver ubicaciones en vivo.';

  @override
  String get signIn => 'Iniciar sesión';

  @override
  String get signUp => 'Crear cuenta';

  @override
  String get signOut => 'Cerrar sesión';

  @override
  String get signInEmailDialogTitle => 'Iniciar sesión con OTP de correo';

  @override
  String get signUpEmailDialogTitle => 'Crear cuenta con OTP de correo';

  @override
  String get signInEmailFieldLabel => 'Correo electrónico';

  @override
  String get signInEmailHint => 'nombre@ejemplo.com';

  @override
  String get signInSendOtp => 'Enviar código';

  @override
  String get signUpSendOtp => 'Enviar código de cuenta';

  @override
  String get signInOtpFieldLabel => 'Código OTP';

  @override
  String get signInOtpHint => 'Código de 6 dígitos';

  @override
  String get signInVerifyOtp => 'Verificar código';

  @override
  String get signInOtpSent => 'Código OTP enviado a tu correo.';

  @override
  String get signUpOtpSent => 'Código de creación de cuenta enviado a tu correo.';

  @override
  String get signInOtpInvalid => 'No se pudo verificar el OTP. Comprueba el código e inténtalo de nuevo.';

  @override
  String get signUpNoAccountAction => '¿No tienes cuenta? Créala';

  @override
  String get signUpHaveAccountAction => '¿Ya tienes cuenta? Inicia sesión';

  @override
  String get authGenericError => 'Algo salió mal. Inténtalo de nuevo.';

  @override
  String get authWelcomeBack => 'Bienvenido de nuevo a CruizX';

  @override
  String get authRegisterSubtitle => 'Únete a la comunidad CruizX';

  @override
  String get authEmailLabel => 'Correo electrónico';

  @override
  String get authEmailRequired => 'Introduce tu correo electrónico';

  @override
  String get authEmailInvalid => 'Correo no válido';

  @override
  String get authPasswordLabel => 'Contraseña';

  @override
  String get authPasswordRequired => 'Introduce tu contraseña';

  @override
  String get authPasswordMinLength => 'Al menos 6 caracteres';

  @override
  String get authConfirmPasswordLabel => 'Confirmar contraseña';

  @override
  String get authConfirmPasswordRequired => 'Confirma tu contraseña';

  @override
  String get authPasswordsDoNotMatch => 'Las contraseñas no coinciden';

  @override
  String get authDisplayNameLabel => 'Nombre de usuario';

  @override
  String get authDisplayNameRequired => 'Introduce tu nombre';

  @override
  String get authNoAccountPrompt => '¿No tienes cuenta? ';

  @override
  String get authAlreadyHaveAccountPrompt => '¿Ya tienes cuenta? ';

  @override
  String get authCancel => 'Cancelar';

  @override
  String get authForgotPasswordLink => '¿Olvidaste tu contraseña?';

  @override
  String get authForgotPasswordTitle => 'Restablecer contraseña';

  @override
  String get authForgotPasswordDescription => 'Introduce tu correo electrónico y te enviaremos un enlace para restablecer tu contraseña.';

  @override
  String get authForgotPasswordButton => 'Enviar enlace de restablecimiento';

  @override
  String get authForgotPasswordSuccess => 'Si la cuenta existe, hemos enviado un enlace de restablecimiento a tu correo.';

  @override
  String get authResetPasswordTitle => 'Nueva contraseña';

  @override
  String get authResetPasswordDescription => 'Introduce tu nueva contraseña a continuación.';

  @override
  String get authNewPasswordLabel => 'Nueva contraseña';

  @override
  String get authResetPasswordButton => 'Guardar contraseña';

  @override
  String get authResetPasswordSuccess => 'Tu contraseña ha sido cambiada.';

  @override
  String get authErrorAllFieldsRequired => 'Todos los campos son obligatorios.';

  @override
  String get authErrorPasswordTooShort => 'La contraseña debe tener al menos 6 caracteres.';

  @override
  String get authErrorConfirmEmail => 'Revisa tu correo para confirmar tu cuenta y luego inicia sesión.';

  @override
  String get authErrorEmailAndPasswordRequired => 'Introduce tu correo y contraseña.';

  @override
  String get authErrorInvalidCredentials => 'Correo o contraseña incorrectos.';

  @override
  String get authErrorEmailAlreadyInUse => 'Ya existe una cuenta con ese correo.';

  @override
  String get convoyRealtimeBackendMissing => 'El convoy en tiempo real aún no está configurado. Añade la configuración del backend para compartir posiciones en vivo entre usuarios.';

  @override
  String get convoyModeTitle => 'Modo Convoy';

  @override
  String get convoyModeSubtitle => 'Conduce en grupo con destino compartido y ubicaciones en vivo.';

  @override
  String get convoyCreateButton => 'Crear convoy';

  @override
  String get convoyOpenButton => 'Abrir';

  @override
  String get convoyJoinButton => 'Unirse';

  @override
  String get convoyLeaveButton => 'Salir';

  @override
  String get convoyJoinFirstHint => 'Únete al convoy primero y luego tócalo para abrir el chat y el mapa.';

  @override
  String get convoyJoinByCodeTitle => 'Unirse a convoy';

  @override
  String get convoyJoinByCodeHint => 'Introduce el código de convoy que recibiste';

  @override
  String get convoyJoinWithCodeButton => 'Unirse';

  @override
  String get convoyJoinByCodeNotFound => 'No se encontró ningún convoy con ese código.';

  @override
  String convoyJoinByCodeSuccess(String name) {
    return '¡Te uniste a $name!';
  }

  @override
  String get convoyInviteButton => 'Invitar';

  @override
  String get convoyTabMap => 'Mapa';

  @override
  String get convoyTabChat => 'Chat';

  @override
  String get convoyMapHint => 'Toca el mapa para colocar un pin compartido.';

  @override
  String get convoyRecenterTooltip => 'Recentrar y seguir mi posición';

  @override
  String get convoyPinDialogTitle => 'Añadir pin al mapa';

  @override
  String get convoyPinLabel => 'Etiqueta del pin';

  @override
  String get convoyPinHint => 'p. ej. Encontrarse aquí';

  @override
  String get convoyPinAdd => 'Añadir pin';

  @override
  String get convoyHazardPolice => 'Policía';

  @override
  String get convoyHazardRoadwork => 'Obras';

  @override
  String get convoyHazardAccident => 'Accidente';

  @override
  String get convoyHazardTrafficJam => 'Atasco';

  @override
  String get convoyHazardSpeedCamera => 'Radar';

  @override
  String get convoyHazardCustom => 'Pin personalizado';

  @override
  String get convoyChatEmpty => 'Aún no hay mensajes.';

  @override
  String get convoyChatPlaceholder => 'Escribe un mensaje...';

  @override
  String get convoyChatSend => 'Enviar';

  @override
  String get convoyNameDialogTitle => 'Crear convoy';

  @override
  String get convoyNameFieldLabel => 'Nombre del convoy';

  @override
  String get convoyNameHint => 'p. ej. Salida del viernes';

  @override
  String get convoyCreateConfirm => 'Crear';

  @override
  String get convoyCreateCancel => 'Cancelar';

  @override
  String get convoyListEmpty => 'Aún no hay convoys. ¡Crea el primero!';

  @override
  String get convoyListEmptyMine => 'Aún no te has unido a ningún convoy.';

  @override
  String get convoyFilterAll => 'Todos';

  @override
  String get convoyFilterMine => 'Míos';

  @override
  String convoyMembers(Object count) {
    return '$count miembros';
  }

  @override
  String get convoyMemberMe => 'Yo';

  @override
  String convoyMemberStaleTime(Object mins) {
    return 'hace $mins min';
  }

  @override
  String convoyCreatedBy(Object leader) {
    return 'Creado por $leader';
  }

  @override
  String get profileTitle => 'Perfil y estadísticas';

  @override
  String get profileNotSignedIn => 'No has iniciado sesión.';

  @override
  String get profileSignInInConvoyHint => 'El inicio de sesión está disponible en la pestaña Convoy.';

  @override
  String profileSignedInAs(Object name) {
    return 'Sesión iniciada como: $name';
  }

  @override
  String get profileDefaultName => 'Conductor CruizX';

  @override
  String get profileSignedIn => 'Sesión iniciada';

  @override
  String get profileStatsTitle => 'Estadísticas';

  @override
  String get profileStatsConvoys => 'Convoys conducidos';

  @override
  String get profileStatsTotalDistance => 'Distancia total';

  @override
  String get profileStatsSpeedViolations => 'Excesos de velocidad';

  @override
  String get profileVehicleTitle => 'Mi vehículo';

  @override
  String get profileVehicleElectric => 'Vehículo eléctrico';

  @override
  String get profileVehicleElectricSubtitle => 'Mostrar estaciones de carga en el mapa';

  @override
  String get profileVehicleStuddedTires => 'Neumáticos con clavos';

  @override
  String get profileVehicleStuddedTiresSubtitle => 'Evitar calles con restricción de neumáticos con clavos';

  @override
  String get settingsTitle => 'Ajustes';

  @override
  String get settingsLanguageLabel => 'Idioma';

  @override
  String get settingsLanguageSystem => 'Predeterminado del sistema';

  @override
  String get settingsLanguageEnglish => 'Inglés';

  @override
  String get settingsLanguageSwedish => 'Sueco';

  @override
  String get settingsLanguageFrench => 'Francés';

  @override
  String get settingsLanguageNorwegian => 'Noruego';

  @override
  String get settingsLanguageDanish => 'Danés';

  @override
  String get settingsLanguageFinnish => 'Finés';

  @override
  String get settingsLanguageSpanish => 'Español';

  @override
  String get settingsCountryLabel => 'País (normas de tráfico)';

  @override
  String get settingsCountrySweden => '🇸🇪 Suecia';

  @override
  String get settingsCountryNorway => '🇳🇴 Noruega';

  @override
  String get settingsCountryDenmark => '🇩🇰 Dinamarca';

  @override
  String get settingsCountryFinland => '🇫🇮 Finlandia';

  @override
  String get settingsCountryFrance => '🇫🇷 Francia';

  @override
  String get settingsCountrySpain => '🇪🇸 España';

  @override
  String get settingsCountryHint => 'Los límites de velocidad y normas de tráfico se adaptan al país seleccionado.';

  @override
  String settingsLanguageCurrentlyUsing(Object mode) {
    return 'Usando actualmente: $mode';
  }

  @override
  String get settingsVehicleTypeLabel => 'Tipo de vehículo';

  @override
  String get settingsVehicleAtractor => 'A-traktor';

  @override
  String get settingsVehicleMopedCar => 'Mopedbil';

  @override
  String get settingsVehicleTractor => 'Traktor';

  @override
  String get settingsSpeedUnitKmh => 'km/h';

  @override
  String get settingsSpeedUnitMph => 'mph';

  @override
  String settingsMaxSpeedWithUnit(Object value, Object unit) {
    return 'Velocidad máx.: $value $unit';
  }

  @override
  String get settingsProCardTitle => 'CruizX Pro';

  @override
  String get settingsProStatusActive => 'Activo';

  @override
  String get settingsProStatusInactive => 'No activo';

  @override
  String get settingsProDescriptionActive => 'Tienes acceso a todas las funciones Pro.';

  @override
  String get settingsProDescriptionInactive => 'Desbloquea todas las funciones con CruizX Pro.';

  @override
  String get settingsProFeatureRoutes => 'Rutas ilimitadas';

  @override
  String get settingsProFeatureConvoy => 'Miembros de convoy ilimitados';

  @override
  String get settingsProFeatureAds => 'Sin anuncios';

  @override
  String get settingsProFeatureSupport => 'Soporte prioritario';

  @override
  String get settingsProSubscriptionNote => 'Suscripción: CruizX Pro mensual (1 mes). El pago se carga en tu Apple ID y se renueva automáticamente salvo cancelación al menos 24 horas antes del final del período actual.';

  @override
  String settingsProPricePerMonth(Object price) {
    return '$price / mes';
  }

  @override
  String get settingsPrivacyPolicyLabel => 'Política de privacidad';

  @override
  String get settingsTermsOfUseLabel => 'Términos de uso (EULA)';

  @override
  String get settingsSupportLabel => 'Soporte';

  @override
  String get settingsLinkOpenFailed => 'No se pudo abrir el enlace ahora mismo.';

  @override
  String get settingsRestorePurchaseFailed => 'No se pudo restaurar la compra.';

  @override
  String get settingsMapMarkerLabel => 'Marcador del mapa';

  @override
  String get settingsMapMarkerCategoryClassic => 'Clásicos';

  @override
  String get settingsMapMarkerCategoryMicrocar => 'Mopedbil';

  @override
  String get settingsMapMarkerCategoryEpa => 'EPA';

  @override
  String get settingsMapMarkerCategoryLigier => 'Ligier';

  @override
  String get settingsMapMarkerCategoryAixam => 'Aixam';

  @override
  String get settingsMapMarkerCategoryPickup => 'Pickup';

  @override
  String get settingsMapMarkerCategoryAtractor => 'A-traktor';

  @override
  String get settingsMapMarkerCategoryTractor => 'Traktor';

  @override
  String get settingsMapMarkerArrow => 'Flecha';

  @override
  String get settingsMapMarkerCompass => 'Brújula';

  @override
  String get settingsMapMarkerTriangle => 'Triángulo';

  @override
  String get settingsMapMarkerDot => 'Punto';

  @override
  String get settingsMapMarkerMicrocar => 'Mopedbil';

  @override
  String get settingsMapMarkerLigier => 'Ligier';

  @override
  String get settingsMapMarkerAixam => 'Aixam';

  @override
  String get settingsMapMarkerPickup => 'Pickup';

  @override
  String get settingsMapMarkerMini => 'MINI';

  @override
  String get settingsMapMarkerBmw => 'BMW';

  @override
  String get settingsMapMarkerTractor => 'Traktor';

  @override
  String get settingsColorRed => 'Rojo';

  @override
  String get settingsColorBlue => 'Azul';

  @override
  String get settingsColorBlack => 'Negro';

  @override
  String get settingsColorWhite => 'Blanco';

  @override
  String get settingsColorGold => 'Oro';

  @override
  String get settingsColorSilver => 'Plata';

  @override
  String get settingsColorGreen => 'Verde';

  @override
  String get settingsColorGraphite => 'Grafito';

  @override
  String get settingsColorYellow => 'Amarillo';

  @override
  String get settingsColorOrange => 'Naranja';

  @override
  String get navigationTitle => 'Navegación paso a paso';

  @override
  String get navigationSubtitle => 'Instrucciones, próximo giro y hora de llegada optimizados para vehículos lentos.';

  @override
  String get mapStartingGps => 'Iniciando GPS...';

  @override
  String get mapTapToSelectDestination => 'Toca el mapa para seleccionar un destino';

  @override
  String get mapAddressFieldHint => 'Buscar dirección (p. ej. Calle Mayor 10, Madrid)';

  @override
  String get mapSearchingAddress => 'Buscando dirección...';

  @override
  String get mapAddressNotFound => 'No se encontró ninguna dirección. Inténtalo de nuevo.';

  @override
  String get mapAddressLookupFailed => 'No se pudo buscar la dirección ahora mismo';

  @override
  String get mapLocationServicesDisabled => 'Los servicios de ubicación están desactivados';

  @override
  String get mapLocationPermissionMissing => 'Falta permiso de ubicación';

  @override
  String get mapGpsActive => 'GPS activo';

  @override
  String get mapGpsUnavailable => 'GPS no disponible en este entorno';

  @override
  String get mapWaitingForGps => 'Esperando señal GPS antes de calcular la ruta';

  @override
  String get mapCalculatingRoute => 'Calculando ruta...';

  @override
  String mapRouteReady(Object distance, Object minutes) {
    return 'Ruta lista: $distance km • $minutes min';
  }

  @override
  String get mapRouteFailed => 'No se pudo crear la ruta ahora mismo';

  @override
  String get mapRemaining => 'restante';

  @override
  String get mapRouteNoRouteFound => 'No se encontró ruta entre los puntos seleccionados';

  @override
  String get mapRouteProviderUnavailable => 'El servicio de rutas no está disponible ahora mismo';

  @override
  String get mapRouteMissingApiKey => 'El enrutamiento no está configurado en el backend (falta la clave API)';

  @override
  String get mapRouteInvalidGeometry => 'Los datos de ruta del servidor no son válidos';

  @override
  String get mapRouteUnknownProvider => 'El proveedor de rutas no está configurado correctamente';

  @override
  String get mapRouteTooFastForVehicle => 'Ruta rechazada: la velocidad media estimada es demasiado alta para este tipo de vehículo.';

  @override
  String get mapRouteNotAllowedForVehicle => 'No se encontró ninguna ruta legalmente conforme para este tipo de vehículo.';

  @override
  String get routeBlockedTitle => 'Ruta no disponible';

  @override
  String routeBlockedBody(Object vehicleType) {
    return 'No se encontró una ruta legal a este destino para tu $vehicleType. El destino puede estar en o solo ser accesible por vías no permitidas para este tipo de vehículo (p. ej. autopistas).';
  }

  @override
  String get routeBlockedOk => 'Aceptar';

  @override
  String get routeBlockedTryOther => 'Probar otro destino';

  @override
  String get mapModeLabel2d => '2D';

  @override
  String get mapModeLabel3d => '3D';

  @override
  String mapManeuverInDistance(Object distance) {
    return 'En $distance';
  }

  @override
  String mapManeuverTowardRoad(Object road) {
    return 'Hacia $road';
  }

  @override
  String get mapSimulateButton => 'Simular';

  @override
  String get speedometerLiveSpeed => 'Velocidad actual';

  @override
  String speedometerMaxSpeedWithUnit(Object value, Object unit) {
    return 'Velocidad máx.: $value $unit';
  }

  @override
  String get speedometerSlowDown => 'Reduce la velocidad.';

  @override
  String get reportAlertTitle => 'Reportar alerta';

  @override
  String get reportAlertDescHint => 'Descripción (opcional)';

  @override
  String get reportAlertSubmit => 'Enviar alerta';

  @override
  String reportAlertNearby(Object type, Object distance) {
    return '$type · $distance m más adelante';
  }

  @override
  String get alertTypePolice => 'Policía';

  @override
  String get alertTypeRoadwork => 'Obras';

  @override
  String get alertTypeAccident => 'Accidente';

  @override
  String get alertTypeTrafficJam => 'Atasco';

  @override
  String get alertTypeSpeedCamera => 'Radar';

  @override
  String get alertTypeHazard => 'Peligro';

  @override
  String get alertTypeNarrowRoad => 'Carretera estrecha';

  @override
  String get alertTypeSteepHill => 'Cuesta pronunciada';

  @override
  String get alertGpsUnavailable => 'GPS aún no disponible';

  @override
  String get alertMustBeLoggedIn => 'Debes iniciar sesión para reportar';

  @override
  String get alertsScreenSubtitle => 'Alertas de otros conductores CruizX en un radio de ~50 km. Toca los pulgares para confirmar una alerta.';

  @override
  String get alertReportButton => 'Reportar';

  @override
  String get alertTimeJustNow => 'Ahora mismo';

  @override
  String alertTimeMinutes(Object n) {
    return 'hace $n min';
  }

  @override
  String alertTimeHours(Object n) {
    return 'hace $n h';
  }

  @override
  String get alertsEmptyTitle => 'Sin alertas activas cerca';

  @override
  String get alertsEmptySubtitle => '¿Ves algo en la carretera? ¡Repórtalo!';

  @override
  String get alertReportQuestion => '¿Qué ves en la carretera?';

  @override
  String get alertReportDescHint2 => 'Descripción opcional… (p. ej. \"rama grande\")';

  @override
  String get alertReportedSuccess => '¡Alerta reportada! Gracias 🙏';

  @override
  String get alertReportFailed => 'No se pudo reportar la alerta ahora mismo.';

  @override
  String get adBannerLoading => 'Cargando anuncio…';

  @override
  String get adBannerWaitingRetry => 'El anuncio está esperando conexión… (toca para reintentar)';

  @override
  String get mapStartNavigation => 'Iniciar navegación';

  @override
  String get mapEndNavigation => 'Finalizar navegación';

  @override
  String get convoyShowAll => 'Mostrar todos';

  @override
  String get convoyYouBadge => 'Tú';

  @override
  String convoyShareCopied(Object name, Object code) {
    return '¡Copiado! Comparte: \"$name\" código: $code';
  }

  @override
  String convoyShareClipboard(Object name, Object code) {
    return 'Convoy CruizX: \"$name\" (código: $code)';
  }

  @override
  String convoyPinMarkedBy(Object name) {
    return 'Marcado por $name';
  }

  @override
  String get convoyNavigateToPin => 'Navegar aquí';

  @override
  String get convoyEtaArrived => '¡Has llegado!';

  @override
  String convoyEtaMinutes(Object minutes, Object time) {
    return '$minutes min · $time';
  }

  @override
  String convoyEtaHours(Object hours, Object minutes, Object time) {
    return '${hours}h ${minutes}min · $time';
  }

  @override
  String get paywallTitle => 'Actualizar a CruizX Pro';

  @override
  String get paywallSubtitle => 'Sin límites. Sin anuncios. Acceso completo.';

  @override
  String get paywallPrice => '39 kr / mes';

  @override
  String get paywallUpgradeButton => 'Actualizar a Pro';

  @override
  String get paywallRestoreButton => 'Restaurar compra';

  @override
  String paywallDisclosure(Object price) {
    return 'CruizX Pro · $price/mes · renovación automática. Cancela en cualquier momento en Ajustes al menos 24 horas antes de la renovación. Se cargará en tu cuenta de Apple ID.';
  }

  @override
  String paywallDisclosureAndroid(Object price) {
    return 'CruizX Pro · $price/mes · renovación automática. Gestionado y facturado a través de Stripe. Cancela en cualquier momento en cruizx.com o contacta con soporte.';
  }

  @override
  String get paywallFreeLabel => 'Gratis';

  @override
  String get paywallProLabel => 'Pro';

  @override
  String get paywallFeatureRoutes => 'Rutas por día';

  @override
  String get paywallFreeRouteLimit => '4 rutas';

  @override
  String get paywallProRouteLimit => 'Ilimitadas';

  @override
  String get paywallFeatureConvoy => 'Convoy';

  @override
  String get paywallFreeConvoyLimit => '1 activo, 2 miembros';

  @override
  String get paywallProConvoyLimit => 'Ilimitado';

  @override
  String get paywallFeatureAds => 'Anuncios';

  @override
  String get paywallFreeAds => 'Mostrados';

  @override
  String get paywallProAds => 'Ninguno';

  @override
  String get paywallRouteLimitTitle => 'Límite de rutas alcanzado';

  @override
  String get paywallRouteLimitBody => 'Los usuarios gratuitos pueden calcular 4 rutas por día. Actualiza a Pro para navegación ilimitada.';

  @override
  String get paywallConvoyLimitTitle => 'Límite de convoy alcanzado';

  @override
  String get paywallConvoyLimitBody => 'Los usuarios gratuitos solo pueden estar en 1 convoy a la vez.';

  @override
  String get paywallMemberLimitTitle => 'Convoy lleno';

  @override
  String get paywallMemberLimitBody => 'Los usuarios gratuitos solo pueden unirse a convoys con menos de 2 miembros. Actualiza a Pro para acceso ilimitado.';

  @override
  String get paywallPurchaseSuccess => '¡Ahora eres usuario Pro!';

  @override
  String get paywallPurchaseFailed => 'No se pudo completar la compra. Verifica tu cuenta de App Store e inténtalo de nuevo.';

  @override
  String get paywallRestoreSuccess => '¡Compra restaurada!';

  @override
  String get paywallLoginRequiredTitle => 'Inicio de sesión requerido';

  @override
  String get paywallLoginRequiredBody => 'Necesitas una cuenta para comprar CruizX Pro. Crea una cuenta gratuita en la aplicación para continuar.';

  @override
  String get paywallLoginRequiredAction => 'OK';

  @override
  String get paywallRestoreNotFound => 'No se encontró ninguna compra anterior.';

  @override
  String get profileFreePlan => 'Plan gratuito';

  @override
  String get profileProPlan => 'Plan Pro';

  @override
  String get profileUpgradeToPro => 'Actualizar a Pro';

  @override
  String profileRoutesUsed(Object count, Object max) {
    return 'Rutas hoy: $count / $max';
  }

  @override
  String get profileChangePhoto => 'Cambiar foto de perfil';

  @override
  String get profileTakePhoto => 'Tomar foto';

  @override
  String get profileChooseFromGallery => 'Elegir de la galería';

  @override
  String get profilePhotoUploadFailed => 'Error al subir la foto';

  @override
  String get parentModeTitle => 'Modo Padres';

  @override
  String get parentModeDescription => 'Permite que un padre siga tu conducción en tiempo real.';

  @override
  String get parentModeLoginRequired => 'Debes iniciar sesión para usar el Modo Padres.';

  @override
  String get parentModeEnable => 'Activar Modo Padres';

  @override
  String get parentModeEnabledSubtitle => 'Los padres pueden seguir tu conducción';

  @override
  String get parentModeDisabledSubtitle => 'Sin compartir activo';

  @override
  String get parentModeInviteCode => 'Código de invitación';

  @override
  String get parentModeInviteCodeSubtitle => 'Comparte este código con tu padre para vincular su cuenta.';

  @override
  String get parentModeCopyCode => 'Copiar';

  @override
  String get parentModeShareCode => 'Compartir';

  @override
  String get parentModeCodeCopied => '¡Código copiado!';

  @override
  String get parentModeShareSubject => 'Código de Padres CruizX';

  @override
  String parentModeShareMessage(Object code) {
    return '¡Hola! Usa este código para seguir mi conducción en CruizX: $code';
  }

  @override
  String get parentModeLinkedParents => 'Padres vinculados';

  @override
  String get parentModeNoParentsLinked => 'Aún no hay padres vinculados. ¡Comparte tu código!';

  @override
  String get parentModeUnlinkTitle => '¿Eliminar padre?';

  @override
  String parentModeUnlinkMessage(Object name) {
    return '¿Quieres eliminar a $name como padre? Ya no podrá seguir tu conducción.';
  }

  @override
  String get parentModeUnlink => 'Eliminar';

  @override
  String get parentModeShareSettings => 'Qué compartir';

  @override
  String get parentModeShareLocation => 'Compartir ubicación';

  @override
  String get parentModeShareLocationSubtitle => 'Mostrar dónde estás en el mapa';

  @override
  String get parentModeShareSpeed => 'Compartir velocidad';

  @override
  String get parentModeShareSpeedSubtitle => 'Mostrar tu velocidad actual';

  @override
  String get parentModeAlertSettings => 'Notificaciones a padres';

  @override
  String get parentModeSpeedAlert => 'Alerta de velocidad';

  @override
  String parentModeSpeedAlertSubtitle(Object limit) {
    return 'Notificar cuando la velocidad supere $limit km/h';
  }

  @override
  String get parentModeSpeedLimit => 'Límite';

  @override
  String get parentModeNightAlert => 'Alerta de conducción nocturna';

  @override
  String parentModeNightAlertSubtitle(Object start, Object end) {
    return 'Notificar cuando conduzca entre $start–$end';
  }

  @override
  String get cancel => 'Cancelar';

  @override
  String get login => 'Iniciar sesión';

  @override
  String get parentDashboardTitle => 'Panel de padres';

  @override
  String get parentDashboardMapTab => 'Mapa';

  @override
  String get parentDashboardAlertsTab => 'Alertas';

  @override
  String get parentDashboardAddChild => 'Añadir hijo';

  @override
  String get parentDashboardOnline => 'En línea';

  @override
  String get parentDashboardOffline => 'Desconectado';

  @override
  String get parentDashboardNoAlerts => 'Sin alertas en las últimas 24 horas';

  @override
  String get parentDashboardNoChildren => 'Aún no hay hijos vinculados';

  @override
  String get parentDashboardNoChildrenHint => 'Añade un hijo introduciendo su código de invitación del Modo Padres de CruizX.';

  @override
  String get parentDashboardEnterCode => 'Introducir código de invitación';

  @override
  String get parentDashboardEnterCodeHint => 'Pide a tu hijo que comparta su código de 6 caracteres desde la configuración del Modo Padres.';

  @override
  String get parentDashboardLink => 'Vincular';

  @override
  String get parentDashboardLinkSuccess => '¡Vinculado correctamente!';

  @override
  String get parentDashboardLinkFailed => 'No se encontró ningún hijo con ese código. Comprueba el código e inténtalo de nuevo.';

  @override
  String get parentDashboardLinkSelf => 'No puedes vincularte a tu propia cuenta. Pide a tu hijo que comparta su código desde su cuenta.';

  @override
  String get parentDashboardSpeedingAlert => 'Alerta de velocidad';

  @override
  String parentDashboardSpeedingDetail(Object name, Object speed, Object limit) {
    return '$name condujo a $speed km/h (límite: $limit km/h)';
  }

  @override
  String get parentDashboardNightAlert => 'Conducción nocturna';

  @override
  String parentDashboardNightDetail(Object name) {
    return '$name está conduciendo de noche';
  }

  @override
  String get parentDashboardViewChild => 'Ver como padre';

  @override
  String get settingsVoiceNavigation => 'Navegación por voz';

  @override
  String get settingsVoiceNavigationSubtitle => 'Leer instrucciones de giro en voz alta';

  @override
  String get voiceTurnLeft => 'Gire a la izquierda';

  @override
  String get voiceTurnRight => 'Gire a la derecha';

  @override
  String get voiceTurnSharpLeft => 'Gire bruscamente a la izquierda';

  @override
  String get voiceTurnSharpRight => 'Gire bruscamente a la derecha';

  @override
  String get voiceTurnSlightLeft => 'Gire ligeramente a la izquierda';

  @override
  String get voiceTurnSlightRight => 'Gire ligeramente a la derecha';

  @override
  String get voiceContinue => 'Continúe recto';

  @override
  String get voiceRoundabout => 'Incorporarse a la rotonda';

  @override
  String get voiceDestination => 'Ha llegado a su destino';

  @override
  String voiceInMeters(Object meters) {
    return 'En $meters metros';
  }

  @override
  String voiceInKm(Object km) {
    return 'En $km kilómetros';
  }

  @override
  String get mfaSetupTitle => 'Activar autenticación de dos factores';

  @override
  String get mfaSetupSubtitle => 'Escanea el código QR con una app de autenticación como Google Authenticator o Authy';

  @override
  String get mfaScanQr => 'Escanea el código de arriba e introduce el código de 6 dígitos a continuación';

  @override
  String get mfaVerifyButton => 'Verificar';

  @override
  String get mfaVerifyTitle => 'Autenticación de dos factores';

  @override
  String get mfaVerifySubtitle => 'Introduce el código de 6 dígitos de tu app de autenticación';

  @override
  String get mfaInvalidCode => 'Código no válido, inténtalo de nuevo';

  @override
  String get mfaCancel => 'Cancelar y cerrar sesión';

  @override
  String get mfaProfileTitle => 'Autenticación de dos factores';

  @override
  String get mfaStatusOn => 'Activada — tu cuenta está protegida';

  @override
  String get mfaStatusOff => 'Desactivada';

  @override
  String get mfaTurnOn => 'Activar';

  @override
  String get mfaTurnOff => 'Desactivar';

  @override
  String get mfaDisableTitle => '¿Desactivar 2FA?';

  @override
  String get mfaDisableBody => 'Tu cuenta será menos segura sin autenticación de dos factores.';

  @override
  String get mfaDisableConfirm => 'Desactivar';

  @override
  String get mfaShowManualKey => '¿No puedes escanear? Mostrar clave manualmente';

  @override
  String get mfaHideManualKey => 'Ocultar clave manual';

  @override
  String get mfaKeyCopied => 'Clave copiada';

  @override
  String get mfaRecommendTitle => 'Protege tu cuenta';

  @override
  String get mfaRecommendBody => 'Recomendamos activar la autenticación de dos factores para proteger tu cuenta. Puedes usar una app de autenticación como Google Authenticator o Authy.';

  @override
  String get mfaRecommendSetup => 'Activar ahora';

  @override
  String get mfaRecommendLater => 'Más tarde';

  @override
  String get favHome => 'Casa';

  @override
  String get favSchool => 'Colegio';

  @override
  String get favWork => 'Trabajo';

  @override
  String get favAddTitle => 'Guardar lugar';

  @override
  String get favLabelHint => 'Nombre (p. ej. Amigo)';

  @override
  String get favSaved => 'Lugar guardado';

  @override
  String get favDeleted => 'Lugar eliminado';

  @override
  String favDeleteConfirm(Object name) {
    return '¿Eliminar $name?';
  }

  @override
  String favSetAs(Object type) {
    return 'Guardar como $type';
  }

  @override
  String get favCustom => 'Otro favorito';

  @override
  String get ttsVoiceHint => 'Consejo: Descarga mejores voces en Ajustes → Accesibilidad → Contenido hablado → Voces';

  @override
  String get ttsVoiceHintDismiss => 'Aceptar';
}
