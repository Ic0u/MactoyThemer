import Foundation

/// Every user-visible string in the app, in each supported language.
///
/// English is the source of truth and the fallback: a key missing a
/// translation falls back to English rather than showing a raw key, so a
/// half-finished translation degrades gracefully instead of breaking the UI.
enum L {
    enum Key {
        // Menu bar
        case menuAbout, menuCheckUpdates, menuAutoCheckUpdates, menuHide, menuHideOthers
        case menuShowAll, menuQuit, menuEdit, menuUndo, menuRedo, menuCut, menuCopy
        case menuPaste, menuSelectAll, menuWindow, menuMinimize, menuZoom, menuClose
        case menuLanguage

        // Workspace tabs
        case tabInstall, tabSettings, tabRemove

        // Device picker
        case deviceLabel, deviceAccessibility, browse, browseTooltip
        case noDeviceFound, notDetectedSuffix, choosePrompt, chooseMessage

        // Install tab
        case themesToInstall, dropListAccessibility, addThemes, clear, clearTooltip
        case install, ready, selectDeviceToApply, choosePanelMessage, noSupportedThemes
        case addedItems, starting, installFailed, couldNotUpdateConfig
        case confirmOverwriteTitle, confirmOverwriteMessage, overwrite, themesHadIssues
        case nothingInstalled, allSkipped, installedCount, skippedCount
        case dropThemesHere, archivesOrFolders

        // Settings tab
        case defaultTheme, displayResolution, saveSettings, randomTheme
        case selectDevice, settingsSaved

        // Remove tab
        case installedTheme, selectThemeToDelete, removeSelectedAccessibility
        case removeAllAccessibility, selectDeviceToManage, noThemesInstalled
        case noThemeSelectedTitle, chooseThemeFirst, deleteThemeTitle, deleteThemeMessage
        case deleteAllTitle, deleteAllMessage, deletedTheme, removedAllThemes
        case deletingTheme, deletingAllThemes
        case deleteFailed, couldNotRemoveTheme

        // Shared
        case cancel, delete, updatesUnavailableTitle, updatesUnavailableMessage
    }

    /// Looks up `key` in the active language, formatting in `arguments` when
    /// the string is a template.
    static func t(_ key: Key, _ arguments: CVarArg...) -> String {
        let language = LocalizationManager.shared.current
        let entry = table[key] ?? [:]
        let format = entry[language] ?? entry[.english] ?? ""
        return arguments.isEmpty ? format : String(format: format, arguments: arguments)
    }

    /// Positional rather than keyed, so each row below stays one readable line.
    /// Order is the language code alphabetically: en, de, es, fr, ja, ru, vi, zh.
    private static func s(
        _ en: String, _ de: String, _ es: String, _ fr: String,
        _ ja: String, _ ru: String, _ vi: String, _ zh: String
    ) -> [AppLanguage: String] {
        [.english: en, .german: de, .spanish: es, .french: fr,
         .japanese: ja, .russian: ru, .vietnamese: vi, .chinese: zh]
    }

    private static let table: [Key: [AppLanguage: String]] = [
        // MARK: - Menu bar
        .menuAbout: s("About %@", "Über %@", "Acerca de %@", "À propos de %@", "%@ について", "О программе %@", "Giới thiệu %@", "关于 %@"),
        // The English wording here is pinned by a test — don't reword it.
        .menuCheckUpdates: s("Check for Updates…", "Nach Updates suchen…", "Buscar actualizaciones…", "Rechercher les mises à jour…", "アップデートを確認…", "Проверить обновления…", "Kiểm tra cập nhật…", "检查更新…"),
        .menuAutoCheckUpdates: s("Automatically Check for Updates", "Automatisch nach Updates suchen", "Buscar actualizaciones automáticamente", "Rechercher automatiquement les mises à jour", "自動的にアップデートを確認", "Автоматически проверять обновления", "Tự động kiểm tra cập nhật", "自动检查更新"),
        .menuHide: s("Hide %@", "%@ ausblenden", "Ocultar %@", "Masquer %@", "%@ を隠す", "Скрыть %@", "Ẩn %@", "隐藏 %@"),
        .menuHideOthers: s("Hide Others", "Andere ausblenden", "Ocultar otros", "Masquer les autres", "ほかを隠す", "Скрыть остальные", "Ẩn các ứng dụng khác", "隐藏其他"),
        .menuShowAll: s("Show All", "Alle einblenden", "Mostrar todo", "Tout afficher", "すべてを表示", "Показать все", "Hiện tất cả", "全部显示"),
        .menuQuit: s("Quit %@", "%@ beenden", "Salir de %@", "Quitter %@", "%@ を終了", "Завершить %@", "Thoát %@", "退出 %@"),
        .menuEdit: s("Edit", "Bearbeiten", "Edición", "Édition", "編集", "Правка", "Chỉnh sửa", "编辑"),
        .menuUndo: s("Undo", "Widerrufen", "Deshacer", "Annuler", "取り消す", "Отменить", "Hoàn tác", "撤销"),
        .menuRedo: s("Redo", "Wiederholen", "Rehacer", "Rétablir", "やり直す", "Повторить", "Làm lại", "重做"),
        .menuCut: s("Cut", "Ausschneiden", "Cortar", "Couper", "カット", "Вырезать", "Cắt", "剪切"),
        .menuCopy: s("Copy", "Kopieren", "Copiar", "Copier", "コピー", "Скопировать", "Sao chép", "拷贝"),
        .menuPaste: s("Paste", "Einsetzen", "Pegar", "Coller", "ペースト", "Вставить", "Dán", "粘贴"),
        .menuSelectAll: s("Select All", "Alles auswählen", "Seleccionar todo", "Tout sélectionner", "すべてを選択", "Выбрать все", "Chọn tất cả", "全选"),
        .menuWindow: s("Window", "Fenster", "Ventana", "Fenêtre", "ウインドウ", "Окно", "Cửa sổ", "窗口"),
        .menuMinimize: s("Minimize", "Im Dock ablegen", "Minimizar", "Réduire", "しまう", "Убрать в Dock", "Thu nhỏ", "最小化"),
        .menuZoom: s("Zoom", "Zoomen", "Zoom", "Réduire/Agrandir", "拡大/縮小", "Масштабировать", "Phóng to", "缩放"),
        .menuClose: s("Close", "Schließen", "Cerrar", "Fermer", "閉じる", "Закрыть", "Đóng", "关闭"),
        .menuLanguage: s("Language", "Sprache", "Idioma", "Langue", "言語", "Язык", "Ngôn ngữ", "语言"),

        // MARK: - Tabs
        .tabInstall: s("Install", "Installieren", "Instalar", "Installer", "インストール", "Установка", "Cài đặt", "安装"),
        .tabSettings: s("Settings", "Einstellungen", "Ajustes", "Réglages", "設定", "Настройки", "Tùy chỉnh", "设置"),
        .tabRemove: s("Remove", "Entfernen", "Eliminar", "Supprimer", "削除", "Удаление", "Gỡ bỏ", "移除"),

        // MARK: - Device picker
        .deviceLabel: s("Device", "Gerät", "Dispositivo", "Appareil", "デバイス", "Устройство", "Thiết bị", "设备"),
        .deviceAccessibility: s("Ventoy device", "Ventoy-Gerät", "Dispositivo Ventoy", "Appareil Ventoy", "Ventoy デバイス", "Устройство Ventoy", "Thiết bị Ventoy", "Ventoy 设备"),
        .browse: s("Browse", "Durchsuchen", "Explorar", "Parcourir", "参照", "Обзор", "Duyệt", "浏览"),
        .browseTooltip: s("Choose a mounted drive or folder", "Ein eingebundenes Laufwerk oder einen Ordner wählen", "Elegir una unidad montada o una carpeta", "Choisir un volume monté ou un dossier", "マウント済みのドライブまたはフォルダを選択", "Выберите подключённый диск или папку", "Chọn ổ đĩa hoặc thư mục đã gắn kết", "选择已挂载的驱动器或文件夹"),
        .noDeviceFound: s("No Ventoy device found", "Kein Ventoy-Gerät gefunden", "No se encontró ningún dispositivo Ventoy", "Aucun appareil Ventoy trouvé", "Ventoy デバイスが見つかりません", "Устройство Ventoy не найдено", "Không tìm thấy thiết bị Ventoy", "未找到 Ventoy 设备"),
        .notDetectedSuffix: s("  — not a detected Ventoy device", "  — kein erkanntes Ventoy-Gerät", "  — no es un dispositivo Ventoy detectado", "  — appareil Ventoy non détecté", "  — Ventoy デバイスとして未検出", "  — не распознано как устройство Ventoy", "  — không phải thiết bị Ventoy được nhận diện", "  — 非已识别的 Ventoy 设备"),
        .choosePrompt: s("Choose", "Auswählen", "Elegir", "Choisir", "選択", "Выбрать", "Chọn", "选择"),
        .chooseMessage: s("Choose the mounted Ventoy device's root folder", "Stammordner des eingebundenen Ventoy-Geräts wählen", "Elige la carpeta raíz del dispositivo Ventoy montado", "Choisissez le dossier racine de l'appareil Ventoy monté", "マウント済み Ventoy デバイスのルートフォルダを選択", "Выберите корневую папку подключённого устройства Ventoy", "Chọn thư mục gốc của thiết bị Ventoy đã gắn kết", "选择已挂载 Ventoy 设备的根文件夹"),

        // MARK: - Install tab
        .themesToInstall: s("Themes to install", "Zu installierende Themes", "Temas por instalar", "Thèmes à installer", "インストールするテーマ", "Темы для установки", "Giao diện sẽ cài", "待安装主题"),
        .dropListAccessibility: s("Themes to install. Drop archives or folders here.", "Zu installierende Themes. Archive oder Ordner hier ablegen.", "Temas por instalar. Arrastra archivos comprimidos o carpetas aquí.", "Thèmes à installer. Déposez des archives ou des dossiers ici.", "インストールするテーマ。アーカイブまたはフォルダをここにドロップ。", "Темы для установки. Перетащите архивы или папки сюда.", "Giao diện sẽ cài. Kéo tệp nén hoặc thư mục vào đây.", "待安装主题。将压缩包或文件夹拖到此处。"),
        .addThemes: s("Add themes…", "Themes hinzufügen…", "Añadir temas…", "Ajouter des thèmes…", "テーマを追加…", "Добавить темы…", "Thêm giao diện…", "添加主题…"),
        .clear: s("Clear", "Leeren", "Vaciar", "Vider", "クリア", "Очистить", "Xóa danh sách", "清空"),
        .clearTooltip: s("Clear the staged list without changing the device", "Liste leeren, ohne das Gerät zu ändern", "Vaciar la lista sin modificar el dispositivo", "Vider la liste sans modifier l'appareil", "デバイスを変更せずに一覧をクリア", "Очистить список, не изменяя устройство", "Xóa danh sách chờ mà không thay đổi thiết bị", "清空待处理列表，不改动设备"),
        .install: s("Install", "Installieren", "Instalar", "Installer", "インストール", "Установить", "Cài đặt", "安装"),
        .ready: s("Ready", "Bereit", "Listo", "Prêt", "準備完了", "Готово", "Sẵn sàng", "就绪"),
        .selectDeviceToApply: s("Select a device to apply themes onto.", "Gerät wählen, auf das Themes angewendet werden.", "Selecciona un dispositivo para aplicar los temas.", "Sélectionnez un appareil sur lequel appliquer les thèmes.", "テーマを適用するデバイスを選択してください。", "Выберите устройство для применения тем.", "Chọn thiết bị để áp dụng giao diện.", "选择要应用主题的设备。"),
        .choosePanelMessage: s("Choose theme archives, or folders containing themes", "Theme-Archive oder Ordner mit Themes wählen", "Elige archivos de temas o carpetas que los contengan", "Choisissez des archives de thèmes ou des dossiers en contenant", "テーマのアーカイブ、またはテーマを含むフォルダを選択", "Выберите архивы тем или папки с темами", "Chọn tệp nén giao diện hoặc thư mục chứa giao diện", "选择主题压缩包或包含主题的文件夹"),
        .noSupportedThemes: s("No supported themes found in that selection.", "Keine unterstützten Themes in der Auswahl gefunden.", "No se encontraron temas compatibles en esa selección.", "Aucun thème pris en charge dans cette sélection.", "選択項目に対応するテーマが見つかりません。", "В выбранном не найдено поддерживаемых тем.", "Không tìm thấy giao diện được hỗ trợ trong lựa chọn đó.", "所选内容中未找到受支持的主题。"),
        .addedItems: s("Added %d item(s).", "%d Objekt(e) hinzugefügt.", "%d elemento(s) añadido(s).", "%d élément(s) ajouté(s).", "%d 項目を追加しました。", "Добавлено объектов: %d.", "Đã thêm %d mục.", "已添加 %d 项。"),
        .starting: s("Starting…", "Wird gestartet…", "Iniciando…", "Démarrage…", "開始しています…", "Запуск…", "Đang bắt đầu…", "正在开始…"),
        .installFailed: s("Install failed.", "Installation fehlgeschlagen.", "Error en la instalación.", "Échec de l'installation.", "インストールに失敗しました。", "Не удалось установить.", "Cài đặt thất bại.", "安装失败。"),
        .couldNotUpdateConfig: s("Could not update ventoy.json", "ventoy.json konnte nicht aktualisiert werden", "No se pudo actualizar ventoy.json", "Impossible de mettre à jour ventoy.json", "ventoy.json を更新できませんでした", "Не удалось обновить ventoy.json", "Không thể cập nhật ventoy.json", "无法更新 ventoy.json"),
        .confirmOverwriteTitle: s("Confirm Overwrite", "Überschreiben bestätigen", "Confirmar sobrescritura", "Confirmer le remplacement", "上書きの確認", "Подтвердите перезапись", "Xác nhận ghi đè", "确认覆盖"),
        .confirmOverwriteMessage: s(
            "Theme '%@' is already installed.\n\nOverwriting replaces it completely — any changes made to it on the device will be lost.",
            "Das Theme '%@' ist bereits installiert.\n\nBeim Überschreiben wird es vollständig ersetzt — alle daran auf dem Gerät vorgenommenen Änderungen gehen verloren.",
            "El tema '%@' ya está instalado.\n\nSobrescribirlo lo reemplaza por completo: se perderán los cambios hechos en el dispositivo.",
            "Le thème '%@' est déjà installé.\n\nLe remplacement l'écrase entièrement — toutes les modifications faites sur l'appareil seront perdues.",
            "テーマ「%@」はすでにインストールされています。\n\n上書きすると完全に置き換えられ、デバイス上で加えた変更はすべて失われます。",
            "Тема «%@» уже установлена.\n\nПерезапись полностью заменит её — все изменения, сделанные на устройстве, будут потеряны.",
            "Giao diện '%@' đã được cài.\n\nGhi đè sẽ thay thế hoàn toàn — mọi thay đổi trên thiết bị sẽ mất.",
            "主题“%@”已安装。\n\n覆盖将完全替换它——设备上对它所做的任何更改都会丢失。"
        ),
        .overwrite: s("Overwrite", "Überschreiben", "Sobrescribir", "Remplacer", "上書き", "Перезаписать", "Ghi đè", "覆盖"),
        .themesHadIssues: s("Some themes had issues", "Bei einigen Themes gab es Probleme", "Algunos temas presentaron problemas", "Certains thèmes ont posé problème", "一部のテーマに問題がありました", "С некоторыми темами возникли проблемы", "Một số giao diện gặp vấn đề", "部分主题存在问题"),
        .nothingInstalled: s("Nothing was installed.", "Es wurde nichts installiert.", "No se instaló nada.", "Rien n'a été installé.", "何もインストールされませんでした。", "Ничего не установлено.", "Không có gì được cài.", "未安装任何内容。"),
        .allSkipped: s("Nothing installed — all themes were skipped.", "Nichts installiert — alle Themes wurden übersprungen.", "No se instaló nada: se omitieron todos los temas.", "Rien d'installé — tous les thèmes ont été ignorés.", "インストールなし — すべてのテーマがスキップされました。", "Ничего не установлено — все темы пропущены.", "Không cài gì — tất cả giao diện đã bị bỏ qua.", "未安装——所有主题均被跳过。"),
        .installedCount: s("Installed %d theme(s).", "%d Theme(s) installiert.", "%d tema(s) instalado(s).", "%d thème(s) installé(s).", "%d 個のテーマをインストールしました。", "Установлено тем: %d.", "Đã cài %d giao diện.", "已安装 %d 个主题。"),
        .skippedCount: s(" Skipped %d.", " %d übersprungen.", " %d omitido(s).", " %d ignoré(s).", " %d 個をスキップ。", " Пропущено: %d.", " Đã bỏ qua %d.", " 已跳过 %d 个。"),
        .dropThemesHere: s("Drop themes here", "Themes hier ablegen", "Arrastra los temas aquí", "Déposez les thèmes ici", "ここにテーマをドロップ", "Перетащите темы сюда", "Kéo giao diện vào đây", "将主题拖到此处"),
        .archivesOrFolders: s("Archives or folders", "Archive oder Ordner", "Archivos comprimidos o carpetas", "Archives ou dossiers", "アーカイブまたはフォルダ", "Архивы или папки", "Tệp nén hoặc thư mục", "压缩包或文件夹"),

        // MARK: - Settings tab
        .defaultTheme: s("Default theme", "Standard-Theme", "Tema predeterminado", "Thème par défaut", "デフォルトのテーマ", "Тема по умолчанию", "Giao diện mặc định", "默认主题"),
        .displayResolution: s("Display resolution", "Bildschirmauflösung", "Resolución de pantalla", "Résolution d'affichage", "画面解像度", "Разрешение экрана", "Độ phân giải hiển thị", "显示分辨率"),
        .saveSettings: s("Save settings", "Einstellungen sichern", "Guardar ajustes", "Enregistrer les réglages", "設定を保存", "Сохранить настройки", "Lưu tùy chỉnh", "保存设置"),
        .randomTheme: s("Random Theme", "Zufälliges Theme", "Tema aleatorio", "Thème aléatoire", "ランダムなテーマ", "Случайная тема", "Giao diện ngẫu nhiên", "随机主题"),
        .selectDevice: s("Select a device.", "Gerät wählen.", "Selecciona un dispositivo.", "Sélectionnez un appareil.", "デバイスを選択してください。", "Выберите устройство.", "Chọn một thiết bị.", "请选择设备。"),
        .settingsSaved: s("Settings saved.", "Einstellungen gesichert.", "Ajustes guardados.", "Réglages enregistrés.", "設定を保存しました。", "Настройки сохранены.", "Đã lưu tùy chỉnh.", "设置已保存。"),

        // MARK: - Remove tab
        .installedTheme: s("Installed theme", "Installiertes Theme", "Tema instalado", "Thème installé", "インストール済みテーマ", "Установленная тема", "Giao diện đã cài", "已安装主题"),
        .selectThemeToDelete: s("Select a theme to delete", "Theme zum Löschen wählen", "Selecciona un tema para eliminar", "Sélectionnez un thème à supprimer", "削除するテーマを選択", "Выберите тему для удаления", "Chọn giao diện để xóa", "选择要删除的主题"),
        .removeSelectedAccessibility: s("Remove selected theme", "Ausgewähltes Theme entfernen", "Eliminar el tema seleccionado", "Supprimer le thème sélectionné", "選択したテーマを削除", "Удалить выбранную тему", "Gỡ giao diện đã chọn", "移除所选主题"),
        .removeAllAccessibility: s("Remove all themes", "Alle Themes entfernen", "Eliminar todos los temas", "Supprimer tous les thèmes", "すべてのテーマを削除", "Удалить все темы", "Gỡ tất cả giao diện", "移除全部主题"),
        .selectDeviceToManage: s("Select a device to manage its themes.", "Gerät wählen, um dessen Themes zu verwalten.", "Selecciona un dispositivo para gestionar sus temas.", "Sélectionnez un appareil pour gérer ses thèmes.", "テーマを管理するデバイスを選択してください。", "Выберите устройство для управления темами.", "Chọn thiết bị để quản lý giao diện.", "选择设备以管理其主题。"),
        .noThemesInstalled: s("No themes installed on this device.", "Auf diesem Gerät sind keine Themes installiert.", "No hay temas instalados en este dispositivo.", "Aucun thème installé sur cet appareil.", "このデバイスにテーマはインストールされていません。", "На этом устройстве нет установленных тем.", "Chưa có giao diện nào trên thiết bị này.", "此设备上未安装主题。"),
        .noThemeSelectedTitle: s("No Theme Selected", "Kein Theme ausgewählt", "Ningún tema seleccionado", "Aucun thème sélectionné", "テーマが未選択", "Тема не выбрана", "Chưa chọn giao diện", "未选择主题"),
        .chooseThemeFirst: s("Choose which theme to delete first.", "Zuerst das zu löschende Theme wählen.", "Elige primero el tema que quieres eliminar.", "Choisissez d'abord le thème à supprimer.", "先に削除するテーマを選択してください。", "Сначала выберите тему для удаления.", "Hãy chọn giao diện cần xóa trước.", "请先选择要删除的主题。"),
        .deleteThemeTitle: s("Delete '%@'?", "'%@' löschen?", "¿Eliminar '%@'?", "Supprimer '%@' ?", "「%@」を削除しますか？", "Удалить «%@»?", "Xóa '%@'?", "删除“%@”？"),
        .deleteThemeMessage: s(
            "This permanently removes the theme folder from the device and its entry from ventoy.json. It cannot be undone.",
            "Dadurch werden der Theme-Ordner vom Gerät und sein Eintrag aus ventoy.json dauerhaft entfernt. Dies kann nicht widerrufen werden.",
            "Esto elimina permanentemente la carpeta del tema del dispositivo y su entrada de ventoy.json. No se puede deshacer.",
            "Cette action supprime définitivement le dossier du thème de l'appareil et son entrée dans ventoy.json. Elle est irréversible.",
            "テーマフォルダをデバイスから、その項目を ventoy.json から完全に削除します。この操作は取り消せません。",
            "Папка темы будет безвозвратно удалена с устройства, а её запись — из ventoy.json. Отменить это невозможно.",
            "Thao tác này xóa vĩnh viễn thư mục giao diện khỏi thiết bị và mục tương ứng trong ventoy.json. Không thể hoàn tác.",
            "这将从设备上永久删除该主题文件夹及其在 ventoy.json 中的条目。此操作无法撤销。"
        ),
        .deleteAllTitle: s("Delete all %d themes?", "Alle %d Themes löschen?", "¿Eliminar los %d temas?", "Supprimer les %d thèmes ?", "%d 個すべてのテーマを削除しますか？", "Удалить все темы (%d)?", "Xóa tất cả %d giao diện?", "删除全部 %d 个主题？"),
        .deleteAllMessage: s(
            "This permanently removes every theme folder from the device and clears them from ventoy.json. It cannot be undone.",
            "Dadurch werden alle Theme-Ordner dauerhaft vom Gerät entfernt und aus ventoy.json gelöscht. Dies kann nicht widerrufen werden.",
            "Esto elimina permanentemente todas las carpetas de temas del dispositivo y las borra de ventoy.json. No se puede deshacer.",
            "Cette action supprime définitivement tous les dossiers de thèmes de l'appareil et les retire de ventoy.json. Elle est irréversible.",
            "すべてのテーマフォルダをデバイスから完全に削除し、ventoy.json からも消去します。この操作は取り消せません。",
            "Все папки тем будут безвозвратно удалены с устройства и очищены из ventoy.json. Отменить это невозможно.",
            "Thao tác này xóa vĩnh viễn mọi thư mục giao diện khỏi thiết bị và xóa chúng khỏi ventoy.json. Không thể hoàn tác.",
            "这将从设备上永久删除所有主题文件夹，并从 ventoy.json 中清除它们。此操作无法撤销。"
        ),
        .deletedTheme: s("Deleted '%@'.", "'%@' gelöscht.", "'%@' eliminado.", "'%@' supprimé.", "「%@」を削除しました。", "«%@» удалена.", "Đã xóa '%@'.", "已删除“%@”。"),
        .removedAllThemes: s("Removed all themes.", "Alle Themes entfernt.", "Se eliminaron todos los temas.", "Tous les thèmes ont été supprimés.", "すべてのテーマを削除しました。", "Все темы удалены.", "Đã gỡ tất cả giao diện.", "已移除全部主题。"),
        .deletingTheme: s("Deleting '%@'…", "'%@' wird gelöscht…", "Eliminando '%@'…", "Suppression de '%@'…", "「%@」を削除中…", "Удаление «%@»…", "Đang xóa '%@'…", "正在删除“%@”…"),
        .deletingAllThemes: s("Deleting all themes…", "Alle Themes werden gelöscht…", "Eliminando todos los temas…", "Suppression de tous les thèmes…", "すべてのテーマを削除中…", "Удаление всех тем…", "Đang xóa tất cả giao diện…", "正在删除全部主题…"),
        .deleteFailed: s("Delete failed.", "Löschen fehlgeschlagen.", "Error al eliminar.", "Échec de la suppression.", "削除に失敗しました。", "Не удалось удалить.", "Xóa thất bại.", "删除失败。"),
        .couldNotRemoveTheme: s("Could not remove theme", "Theme konnte nicht entfernt werden", "No se pudo eliminar el tema", "Impossible de supprimer le thème", "テーマを削除できませんでした", "Не удалось удалить тему", "Không thể gỡ giao diện", "无法移除主题"),

        // MARK: - Shared
        .cancel: s("Cancel", "Abbrechen", "Cancelar", "Annuler", "キャンセル", "Отменить", "Hủy", "取消"),
        .delete: s("Delete", "Löschen", "Eliminar", "Supprimer", "削除", "Удалить", "Xóa", "删除"),
        .updatesUnavailableTitle: s("Updates unavailable", "Updates nicht verfügbar", "Actualizaciones no disponibles", "Mises à jour indisponibles", "アップデートを利用できません", "Обновления недоступны", "Không có cập nhật", "更新不可用"),
        .updatesUnavailableMessage: s(
            "Automatic updates are not available in this build. Please check the app's download page for a newer version.",
            "In dieser Version sind automatische Updates nicht verfügbar. Bitte prüfe die Download-Seite der App auf eine neuere Version.",
            "Las actualizaciones automáticas no están disponibles en esta versión. Consulta la página de descargas de la app para ver si hay una versión más reciente.",
            "Les mises à jour automatiques ne sont pas disponibles dans cette version. Consultez la page de téléchargement de l'app pour une version plus récente.",
            "このビルドでは自動アップデートを利用できません。アプリのダウンロードページで新しいバージョンをご確認ください。",
            "В этой сборке автоматические обновления недоступны. Проверьте страницу загрузки приложения на наличие новой версии.",
            "Bản dựng này không hỗ trợ cập nhật tự động. Vui lòng kiểm tra trang tải về để xem phiên bản mới hơn.",
            "此版本不支持自动更新。请前往应用下载页面查看更新版本。"
        )
    ]
}

extension L.Key: Hashable {}
