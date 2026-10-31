# Windows Master Optimizer Ultra v6.1

Высокопроизводительный комплекс тонкой настройки ядра NT, подсистем памяти, дискового I/O, графического конвейера DWM и устранения задержек (DPC/ISR Jitter) в Windows 10/11.

## Основные возможности

1. **Комплексная ультра-оптимизация (All-in-One)**:
   - Калибровка таймеров Invariant TSC и стабилизация `timeBeginPeriod(1)`.
   - Настройка `Win32PrioritySeparation (0x26)`, `Multimedia SystemProfile` и отключение `PowerThrottling`.
   - Оптимизация дискового стека, Disable8dot3, NtfsMftZoneReservation и прямых очередей Direct I/O.
   - Удержание ядра в физической памяти (`DisablePagingExecutive = 1`), запрет сжатия памяти (`Disable-MMAgent`).
   - Аппаратный IRQ Affinity Steering и изоляция прерываний GPU / USB.
   - Оптимизация мыши MarkC 1:1, отключение Enhanced Pointer Precision.
   - Изоляция аудиоподсистемы (`audiodg.exe`) в реальном времени.
   - Автоподбор и привязка Java-сред (Minecraft / SyntaxClient / PrismLauncher) к дискретному GPU.

2. **Модуль ревитализации и сброса деградации аптайма (Uptime Anti-Rot)**:
   - Мягкий перезапуск DWM (`taskkill /f /im dwm.exe`) за 150 мс с пересозданием чистых DirectX swapchains и сбросом VRAM.
   - Выгрузка зависших фоновых хостов XAML (`TextInputHost`, `SearchHost`, `StartMenuExperienceHost`, `Widgets`).
   - Сброс утечек аудиодвижка `audiodg.exe` и кэша шрифтов `FontCache`.
   - Сброс DNS/NetBIOS резолвера (`Clear-DnsClientCache`).
   - Нативный NT-сброс Standby-листа RAM и системных рабочих наборов (`[WinNativeOptimizer]::FlushStandbyList()`).
   - Отключение Fast Startup (`HiberbootEnabled = 0`) для гарантии 100% холодного чистого старта при каждом выключении.

3. **Глубокий клининг и деблоат**:
   - Вырезка рекламы UWP, отключение телеметрии и фоновых сборщиков.
   - Очистка очередей отчетов WER, дампов сбоев и кэшей.

4. **Инженерный профайлер и стресс-скан**:
   - Экспресс-замер задержек и расчет Gaming Index (0-100).
   - Глубокий стресс-тест CPU, памяти и 4K Direct I/O с расчетом p99.

## Безопасность и целостность
- Резервное копирование: автоматическое создание System Restore Point и экспорт веток реестра перед изменениями.
- Защита сетевого стека: VPN-туннели, прокси-маршруты и сетевые адаптеры полностью изолированы и не сбрасываются.
- Исполнение в RAM: Zero-Disk Footprint без создания временных `.ps1` файлов на диске.

## Запуск
Запустите `Windows_Master_Optimizer.bat` от имени Администратора.
