enum AppLanguage {
  en('English'),
  ru('Russian');

  const AppLanguage(this.label);

  final String label;
}

class AppStrings {
  const AppStrings._(this.appLanguage);

  factory AppStrings.forLanguage(AppLanguage language) {
    return AppStrings._(language);
  }

  final AppLanguage appLanguage;

  bool get _ru => appLanguage == AppLanguage.ru;

  String get appTitle => 'Anycast Scout by Pingle';
  String get productName => 'anycast-scout';
  String get windowTitle => 'Anycast Scout by Pingle';
  String get probeEngine => _ru ? 'Probe Engine' : 'Probe Engine';
  String get tagline => _ru
      ? 'Компактный рабочий стол для поиска и проверки edge IP.'
      : 'Compact desktop workflow for discovering and validating edge IPs.';
  String get start => _ru ? 'Старт' : 'Start';
  String get continueTimeoutFallback =>
      _ru ? 'Продолжить timeout fallback' : 'Continue timeout fallback';
  String get checkCandidates =>
      _ru ? 'Проверить кандидаты' : 'Check candidates';
  String get clearCandidateChecks =>
      _ru ? 'Очистить Connect-результаты' : 'Clear Connect results';
  String get openSession => _ru ? 'Открыть сессию...' : 'Open session...';
  String get starting => _ru ? 'Запуск' : 'Starting';
  String get stop => _ru ? 'Стоп' : 'Stop';
  String get stopping => _ru ? 'Остановка' : 'Stopping';
  String get csv => 'CSV';
  String get usableCsv => _ru ? 'CSV рабочих IP' : 'Usable CSV';
  String get artifacts => _ru ? 'Артефакты' : 'Artifacts';
  String get files => _ru ? 'Файлы' : 'Files';
  String get dashboard => _ru ? 'Дашборд' : 'Dashboard';
  String get journal => _ru ? 'Журнал' : 'Journal';
  String get sessions => _ru ? 'Сессии' : 'Sessions';
  String get settings => _ru ? 'Настройки' : 'Settings';
  String get about => _ru ? 'О приложении' : 'About';
  String get minimize => _ru ? 'Свернуть' : 'Minimize';
  String get maximize => _ru ? 'Развернуть' : 'Maximize';
  String get close => _ru ? 'Закрыть' : 'Close';
  String get status => _ru ? 'Статус' : 'Status';
  String get contentStatusReady => _ru ? 'Готов' : 'Ready';
  String get contentStatusRestoring => _ru ? 'Восстановление' : 'Restoring';
  String get statusLabel => _ru ? 'Статус:' : 'Status:';
  String get targetIpsLabel => _ru ? 'Целей:' : 'Target IPs:';
  String get validIpsLabel => _ru ? 'Валидных:' : 'Valid IPs:';
  String get estimatedLabel => _ru ? 'Оценка:' : 'Estimated:';
  String get elapsedLabel => _ru ? 'Прошло:' : 'Elapsed:';
  String get idle => _ru ? 'Ожидание' : 'Idle';
  String get running => _ru ? 'В работе' : 'Running';
  String get ready => _ru ? 'Готово' : 'Ready';
  String get failed => _ru ? 'Ошибка' : 'Failed';
  String get discoveryRunning => _ru ? 'Discovery идет' : 'Discovery running';
  String get connectRunning => _ru ? 'Connect идет' : 'Connect running';
  String get warningStatus => _ru ? 'Предупреждение' : 'Warning';
  String get dismissError => _ru ? 'Скрыть ошибку' : 'Dismiss error';
  String get metricsTargets => _ru ? 'цели' : 'targets';
  String get metricsScanned => _ru ? 'проверено' : 'scanned';
  String get metricsCandidates => _ru ? 'кандидаты' : 'candidates';
  String get metricsTested => _ru ? 'Connect tested' : 'Connect tested';
  String get metricsPending => _ru ? 'ожидают' : 'pending';
  String get metricsScanOk => _ru ? 'scan ok' : 'scan ok';
  String get metricsSingBoxOk => _ru ? 'Connect ok' : 'Connect ok';
  String get metricsUsable => _ru ? 'годные' : 'usable';
  String get metricsTime => _ru ? 'время' : 'time';
  String get workflowDiscovery => _ru ? 'Discovery' : 'Discovery';
  String get workflowScan => _ru ? 'Scan' : 'Scan';
  String get workflowSingBox => 'Connect';
  String get workflowPending => _ru ? 'Ожидание' : 'Pending';
  String get workflowActive => _ru ? 'В работе' : 'Active';
  String get workflowDone => _ru ? 'Готово' : 'Done';
  String get workflowRestored => _ru ? 'Восстановлено' : 'Restored';
  String get usableIps => _ru ? 'Рабочие IP' : 'Usable IPs';
  String readyForConnection(int count) =>
      _ru ? '$count готово к подключению' : '$count ready for connection';
  String get activity => _ru ? 'Активность' : 'Activity';
  String lines(int count) => _ru ? '$count строк' : '$count lines';
  String get noUsableIps => _ru
      ? 'Рабочих IP пока нет. Запустите процесс или восстановите артефакты.'
      : 'No usable IPs yet. Start the workflow or resume from session artifacts.';
  String get noLogs => _ru
      ? 'Здесь появятся события discovery, scan и Connect.'
      : 'Logs appear here while discovery, scan, and Connect checks run.';
  String get scanRunning => _ru ? 'Сканирование идет' : 'Scan running';
  String get scanStartingStatus =>
      _ru ? 'Сканирование запускается' : 'Scanning is starting';
  String get discoveryStartingStatus =>
      _ru ? 'Discovery собирает цели' : 'Discovery is collecting targets';
  String get connectStartingStatus =>
      _ru ? 'Connect проверяет кандидаты' : 'Connect checks are running';
  String get statusInProgress => _ru ? 'Выполняется...' : 'In progress...';
  String scanningNoValidStatus(String scanned) => _ru
      ? 'Валидных IP пока нет. Проверено: $scanned. $statusInProgress'
      : 'No valid IPs found yet. $scanned checked. $statusInProgress';
  String scanningValidStatus(String valid, String scanned) => _ru
      ? 'Найдено валидных IP: $valid из $scanned проверенных. $statusInProgress'
      : '$valid valid IPs found from $scanned checked. $statusInProgress';
  String discoveryTargetsStatus(String targets) => _ru
      ? 'Подготовлено целей: $targets. $statusInProgress'
      : '$targets target IPs prepared. $statusInProgress';
  String connectProgressStatus(String valid, String usable) => _ru
      ? 'Connect проверяет $valid scan-valid кандидатов. Рабочих: $usable. $statusInProgress'
      : 'Connect is checking $valid scan-valid candidates. $usable usable. $statusInProgress';
  String get warningProgressStatus => _ru
      ? 'Получено предупреждение. Подробности доступны в журнале.'
      : 'Warning received. Details are available in Journal.';
  String get noUsableIpsYet =>
      _ru ? 'Рабочих IP пока нет' : 'No usable IPs yet';
  String get scanNotStarted =>
      _ru ? 'Сканирование не запущено' : 'Scan not started';
  String get awaitingExecution => _ru
      ? 'Ожидание запуска. Нажмите Start, чтобы начать probe.'
      : 'Awaiting execution. Click Start to begin probe.';
  String get scanRunningPrompt => _ru
      ? 'Discovery и проверка выполняются. Результаты появятся здесь.'
      : 'Discovery and validation are in progress. Results will appear here.';
  String get noUsablePrompt => _ru
      ? 'Рабочие IP еще не найдены. Текущий вывод доступен в журнале.'
      : 'The workflow has not produced usable IPs yet. Check Journal for current output.';
  String get scanNotStartedPrompt => _ru
      ? 'Запустите workflow, чтобы найти и проверить Cloudflare edge targets.'
      : 'Start a workflow to discover and validate Cloudflare edge targets.';
  String get ip => 'IP';
  String get ipAddress => _ru ? 'IP-адрес' : 'IP Address';
  String get rating => _ru ? 'Рейтинг' : 'Rating';
  String get latency => _ru ? 'Latency' : 'Latency';
  String get speed => _ru ? 'Speed' : 'Speed';
  String get delay => _ru ? 'Delay' : 'Delay';
  String get download => _ru ? 'Download' : 'Download';
  String get verified => _ru ? 'Проверено' : 'Verified';
  String get asn => 'ASN';
  String get prefix => _ru ? 'Префикс' : 'Prefix';
  String get paths => _ru ? 'Пути' : 'Paths';
  String get pathsDescription => _ru
      ? 'Локальные бинарные файлы и файлы workflow.'
      : 'Local binaries and workflow files.';
  String get application => _ru ? 'Приложение' : 'Application';
  String get aboutDescription =>
      _ru ? 'Сведения о продукте и команде.' : 'Product and team information.';
  String get applicationName => _ru ? 'Название' : 'Name';
  String get guiVersion => _ru ? 'Версия GUI' : 'GUI version';
  String get anycastScoutCoreVersion =>
      _ru ? 'Версия ядра Anycast Scout' : 'Anycast Scout core version';
  String get singBoxCoreVersion =>
      _ru ? 'Версия ядра sing-box' : 'sing-box core version';
  String get developers => _ru ? 'Разработчики' : 'Developers';
  String get pingleSoftware => 'Pingle Software';
  String get iconAttribution => _ru ? 'Иконка' : 'Icon';
  String get fontAwesomeAttribution => _ru
      ? 'Font Awesome Free Tower Broadcast (CC BY 4.0)'
      : 'Font Awesome Free Tower Broadcast (CC BY 4.0)';
  String get website => _ru ? 'Сайт' : 'Website';
  String get pingleWebsite => 'https://pingle.one/';
  String get targeting => _ru ? 'Цели' : 'Targeting';
  String get targetingDescription => _ru
      ? 'Ограничения и правила расширения списка целей.'
      : 'Limits and expansion rules for produced targets.';
  String get core => _ru ? 'Ядро' : 'Core';
  String get anycastScoutRustBinary => 'Anycast Scout Rust binary';
  String get coreBinary => _ru ? 'Бинарь ядра' : 'Core binary';
  String get singBoxBinary => _ru ? 'Sing-box binary' : 'Sing-box binary';
  String get sessionFile => _ru ? 'Файл сессии' : 'Session file';
  String get discovery => _ru ? 'Discovery' : 'Discovery';
  String get discoveryDescription => _ru
      ? 'ASN-источники и scope для сбора целей.'
      : 'ASN sources and scope for target collection.';
  String get discoveryProfile => _ru ? 'Профиль ASN' : 'ASN profile';
  String get cloudflareCandidates => _ru ? 'Cloudflare' : 'Cloudflare';
  String get customAsns => _ru ? 'Свой' : 'Custom';
  String get asnList => _ru ? 'Список ASN' : 'ASN list';
  String get scope => _ru ? 'Диапазон поиска' : 'BGP scope';
  String get scopeOrigin => _ru ? 'ORIGIN' : 'ORIGIN';
  String get scopeAsPath => _ru ? 'BYOIP' : 'BYOIP';
  String get scopeOriginAndAsPath => _ru ? 'ALL' : 'ALL';
  String get scopeOriginHint => _ru
      ? 'Только префиксы, где выбранный ASN является origin ASN.'
      : 'Only prefixes where the selected ASN is the origin ASN.';
  String get scopeAsPathHint => _ru
      ? 'Префиксы, где ASN встречается в AS_PATH, но не является origin. Полезно для BYOIP/customer-кандидатов.'
      : 'Prefixes where the ASN appears in AS_PATH but is not the origin. Useful for BYOIP/customer candidates.';
  String get scopeOriginAndAsPathHint => _ru
      ? 'ORIGIN + BYOIP: самый широкий набор кандидатов.'
      : 'ORIGIN + BYOIP: the broadest candidate set.';
  String get on => _ru ? 'Вкл' : 'On';
  String get off => _ru ? 'Выкл' : 'Off';
  String get expandAllHosts => _ru ? 'Все IPv4 хосты' : 'Expand all hosts';
  String get expandAllHostsHint => _ru
      ? 'Разворачивать найденные IPv4 CIDR-префиксы во все адреса внутри них. Включено по умолчанию.'
      : 'Expand discovered IPv4 CIDR prefixes into every address inside them. Enabled by default.';
  String get maxIpsHint => _ru
      ? 'Пусто: без лимита. Число: остановиться после N сгенерированных IP.'
      : 'Empty: no cap. Number: stop after N generated IPs.';
  String get limitTargetCount => _ru ? 'Ограничить цели' : 'Limit target count';
  String get maxIps => _ru ? 'Макс. IP' : 'Max IPs';
  String get validation => _ru ? 'Проверка' : 'Validation';
  String get validationDescription => _ru
      ? 'Параллельность и пороги download-проверки.'
      : 'Concurrency and download validation thresholds.';
  String get scanConcurrency =>
      _ru ? 'Параллельность scan' : 'Scan concurrency';
  String get scanConcurrencyHint => _ru
      ? 'Сколько scan-проверок выполнять параллельно.'
      : 'How many scan probes run in parallel.';
  String get singBoxConcurrency =>
      _ru ? 'Параллельность Connect' : 'Connect concurrency';
  String get singBoxConcurrencyHint => _ru
      ? 'Сколько Connect urltest проверок запускать параллельно.'
      : 'How many Connect urltest checks run in parallel.';
  String get timeoutFallbackBudget =>
      _ru ? 'Лимит timeout fallback' : 'Timeout fallback budget';
  String get timeoutFallbackBudgetHint => _ru
      ? 'Сколько direct-timeout IP дополнительно прогонять через optional Connect fallback после основного scan.'
      : 'How many direct-timeout IPs to send through the optional Connect fallback after the primary scan.';
  String get maxUsableResults =>
      _ru ? 'Макс. рабочих результатов' : 'Max usable results';
  String get maxUsableResultsHint => _ru
      ? 'Пусто: сканировать без лимита. Число: остановиться после N рабочих результатов.'
      : 'Empty: scan without a cap. Number: stop after N usable results.';
  String get speedUrl => _ru ? 'Speed URL' : 'Speed URL';
  String get speedUrlHint => _ru
      ? 'Опциональный URL для speed-test через candidate IP.'
      : 'Optional speed-test URL resolved through the candidate IP.';
  String get downloadUrl => _ru ? 'Download URL' : 'Download URL';
  String get downloadUrlHint => _ru
      ? 'URL для проверки минимальной загрузки через candidate IP.'
      : 'URL used for minimum download validation through the candidate IP.';
  String get minDownloadBytes =>
      _ru ? 'Мин. байт загрузки' : 'Min download bytes';
  String get minDownloadBytesHint => _ru
      ? 'Сколько байт нужно скачать, чтобы результат считался рабочим. 0 отключает проверку.'
      : 'Bytes that must download for a result to be usable. 0 disables the check.';
  String get singBox => 'Connect';
  String get singBoxDescription => _ru
      ? 'Config и outbound для Connect-проверки.'
      : 'Config and outbound for Connect checks.';
  String get configPath => _ru ? 'Путь config' : 'Config path';
  String get outboundTag => _ru ? 'Outbound tag' : 'Outbound tag';
  String get noOutboundsInConfig =>
      _ru ? 'В config нет outbounds' : 'No outbounds in config';
  String get browse => _ru ? 'Выбрать' : 'Browse';
  String get terminal => _ru ? 'Терминал' : 'Terminal';
  String get liveWorkflow => _ru ? 'live workflow' : 'live workflow';
  String get sessionJournal => _ru ? 'журнал сессии' : 'session journal';
  String get noTerminalOutput =>
      _ru ? 'Вывода терминала пока нет.' : 'No terminal output yet.';
  String get specificSingBoxMissingPrefix => _ru
      ? 'Локальный Connect config не найден:'
      : 'Local Connect config is missing:';

  String get savedSessions => _ru ? 'Сохраненные сессии' : 'Saved Sessions';
  String get noSavedSessions =>
      _ru ? 'Session JSON не найдены.' : 'No session JSON files found.';
  String get sessionFileColumn => _ru ? 'session file' : 'session file';
  String get savedAtColumn => _ru ? 'saved at' : 'saved at';
  String get sessionStatusColumn => _ru ? 'status' : 'status';
  String get sessionTargetsColumn => _ru ? 'targets' : 'targets';
  String get sessionScanUsableColumn =>
      _ru ? 'scan results / usable' : 'scan results / usable';
  String get sessionConnectColumn =>
      _ru ? 'Connect results / ok' : 'Connect results / ok';
  String get actionsColumn => _ru ? 'actions' : 'actions';
  String get continueSessionAction => _ru ? 'Continue' : 'Continue';
  String get revealAction => _ru ? 'Reveal' : 'Reveal';
  String get refreshSessions => _ru ? 'Обновить сессии' : 'Refresh sessions';

  String singBoxConfigMissing(String path) =>
      '$specificSingBoxMissingPrefix $path';
}
