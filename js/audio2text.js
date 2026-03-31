(function() {

	console.log('[Audio2Text] Script v16 - added Whisper engine support');

	// Detect user language
	var userLang = (OC.getLanguage && OC.getLanguage()) || navigator.language || navigator.userLanguage || 'en';
	userLang = userLang.toLowerCase();
	var isRussian = userLang.startsWith('ru');

	// Full localization including all status messages
	var t = isRussian ? {
		// UI
		statusBarTitle: '🎤 Распознавание речи',
		statusBarMinimized: 'Статус распознавания',
		minimize: 'Свернуть',
		expand: 'Развернуть',
		showDetails: 'Подробнее',
		hideDetails: 'Скрыть',
		cancel: 'Отмена',
		eventHistory: 'История событий:',
		cancelConfirm: 'Отменить распознавание для "{filename}"?',
		dialogTitle: 'Распознавание речи',
		engine: 'Движок распознавания:',
		engineYandex: 'Yandex SpeechKit',
		engineWhisper: 'Whisper (локально)',
		whisperModel: 'Модель Whisper:',
		whisperNote: '⚠️ Whisper работает локально на CPU — обработка может занять длительное время',
		language: 'Язык распознавания:',
		languageAuto: 'Автоопределение',
		numbersAsWords: 'Числа словами',
		profanityFilter: 'Фильтр ненормативной лексики',
		autoPunctuation: 'Автоматическая расстановка точек',
		createSubtitles: 'Создать субтитры (SRT)',
		saveToFolder: 'Сохранить в:',
		chooseFolder: 'Выбрать папку',
		chooseFolderTitle: 'Выберите папку для результата',
		cancelBtn: 'Отмена',
		startBtn: 'Начать распознавание',
		bulkButton: '🎤 Распознать выбранное',
		bulkConfirm: 'Начать распознавание для {count} файл(ов)?',
		bulkTitle: 'Массовое распознавание речи',
		noFiles: 'Не выбрано ни одного файла',
		noMedia: 'Среди выбранных файлов нет аудио/видео',
		recognizeSpeech: 'Распознать речь',
		cannotProcessOpus: 'Невозможно обработать .opus файлы',

		// Status messages
		initializing: 'Инициализация...',
		processing: 'Обработка...',
		taskCreated: '🎬 Задача создана',
		taskCancelled: '❌ Отменено',
		taskCompleted: '✅ Завершено',
		taskFailed: '❌ Ошибка: {error}',

		// Detailed status translations
		analyzingFile: 'Анализ файла...',
		convertingAudio: 'Конвертация аудио...',
		speedingUp: 'Ускорение аудио (10x)...',
		extractingAudio: 'Извлечение аудиодорожки...',
		uploadingToS3: 'Загрузка в Yandex Cloud S3...',
		creatingTask: 'Создание задачи распознавания...',
		recognitionStarted: 'Распознавание речи (Yandex SpeechKit)...',
		waitingResults: 'Ожидание результатов...',
		downloadingResults: 'Загрузка результатов...',
		processingResults: 'Обработка результатов...',
		finalizingTranscription: 'Финализация транскрипции...',
		updatingIndex: 'Обновление индекса ownCloud...',
		sendingNotifications: 'Отправка уведомлений...',

		// Whisper status translations
		loadingWhisperModel: 'Загрузка модели Whisper...',
		whisperTranscribing: 'Распознавание (Whisper)...',
		whisperProcessingResults: 'Обработка результатов Whisper...',

		estimatedTime: '≈ {time}',
		waitingForYandex: '(зависит от очереди Яндекса)',
		completedOf: '{completed} из {total}',
		totalEstimatedTime: 'Всего ≈ {time}',

		// Languages
		languageRussian: 'Русский',
		languageEnglish: 'English',
		languageKazakh: 'Қазақша',
		languageTurkish: 'Türkçe',
		languageUzbek: 'Oʻzbekcha',
		languageHebrew: 'עברית',
		languageArabic: 'العربية',
		languageGerman: 'Deutsch',
		languageSpanish: 'Español',
		languageFrench: 'Français',
		languageItalian: 'Italiano',
		languagePortuguese: 'Português',
		languagePolish: 'Polski',
		languageDutch: 'Nederlands',
		languageSwedish: 'Svenska',

		errorGeneric: 'Ошибка',
		filesListUnavailable: 'Список файлов недоступен',
		errorPrefix: 'Ошибка: '
	} : {
		// UI
		statusBarTitle: '🎤 Speech Recognition',
		statusBarMinimized: 'Recognition Status',
		minimize: 'Minimize',
		expand: 'Expand',
		showDetails: 'Details',
		hideDetails: 'Hide',
		cancel: 'Cancel',
		eventHistory: 'Event history:',
		cancelConfirm: 'Cancel recognition for "{filename}"?',
		dialogTitle: 'Speech recognition',
		engine: 'Recognition engine:',
		engineYandex: 'Yandex SpeechKit',
		engineWhisper: 'Whisper (local)',
		whisperModel: 'Whisper model:',
		whisperNote: '⚠️ Whisper runs locally on CPU — processing may take a long time',
		language: 'Recognition language:',
		languageAuto: 'Auto-detect',
		numbersAsWords: 'Numbers as words',
		profanityFilter: 'Profanity filter',
		autoPunctuation: 'Automatic punctuation',
		createSubtitles: 'Create subtitles (SRT)',
		saveToFolder: 'Save to:',
		chooseFolder: 'Choose folder',
		chooseFolderTitle: 'Select output folder',
		cancelBtn: 'Cancel',
		startBtn: 'Start recognition',
		bulkButton: '🎤 Recognize selected',
		bulkConfirm: 'Start recognition for {count} file(s)?',
		bulkTitle: 'Bulk Speech Recognition',
		noFiles: 'No files selected',
		noMedia: 'No audio/video files among selected',
		recognizeSpeech: 'Recognize speech',
		cannotProcessOpus: 'Cannot process .opus files',

		// Status messages
		initializing: 'Initializing...',
		processing: 'Processing...',
		taskCreated: '🎬 Task created',
		taskCancelled: '❌ Cancelled',
		taskCompleted: '✅ Completed',
		taskFailed: '❌ Error: {error}',

		// Detailed status translations
		analyzingFile: 'Analyzing file...',
		convertingAudio: 'Converting audio...',
		speedingUp: 'Speeding up audio (10x)...',
		extractingAudio: 'Extracting audio track...',
		uploadingToS3: 'Uploading to Yandex Cloud S3...',
		creatingTask: 'Creating recognition task...',
		recognitionStarted: 'Speech recognition (Yandex SpeechKit)...',
		waitingResults: 'Waiting for results...',
		downloadingResults: 'Downloading results...',
		processingResults: 'Processing results...',
		finalizingTranscription: 'Finalizing transcription...',
		updatingIndex: 'Updating ownCloud index...',
		sendingNotifications: 'Sending notifications...',

		// Whisper status translations
		loadingWhisperModel: 'Loading Whisper model...',
		whisperTranscribing: 'Transcribing (Whisper)...',
		whisperProcessingResults: 'Processing Whisper results...',

		estimatedTime: '≈ {time}',
		waitingForYandex: '(depends on Yandex queue)',
		completedOf: '{completed} of {total}',
		totalEstimatedTime: 'Total ≈ {time}',

		// Languages
		languageRussian: 'Russian (Русский)',
		languageEnglish: 'English',
		languageKazakh: 'Kazakh (Қазақша)',
		languageTurkish: 'Turkish (Türkçe)',
		languageUzbek: 'Uzbek (Oʻzbekcha)',
		languageHebrew: 'Hebrew (עברית)',
		languageArabic: 'Arabic (العربية)',
		languageGerman: 'German (Deutsch)',
		languageSpanish: 'Spanish (Español)',
		languageFrench: 'French (Français)',
		languageItalian: 'Italian (Italiano)',
		languagePortuguese: 'Portuguese BR (Português)',
		languagePolish: 'Polish (Polski)',
		languageDutch: 'Dutch (Nederlands)',
		languageSwedish: 'Swedish (Svenska)',

		errorGeneric: 'Error',
		filesListUnavailable: 'File list not available',
		errorPrefix: 'Error: '
	};

	// Status translation map
	var statusTranslations = {
		'Analyzing file...': t.analyzingFile,
		'Converting and speeding up audio (10x faster)...': t.speedingUp,
		'Converting audio...': t.convertingAudio,
		'Extracting audio track from video...': t.extractingAudio,
		'Uploading to Yandex Cloud S3...': t.uploadingToS3,
		'Starting speech recognition (Yandex SpeechKit)...': t.recognitionStarted,
		'Speech recognition in progress (Yandex SpeechKit)...': t.recognitionStarted,
		'Waiting for recognition results...': t.waitingResults,
		'Downloading recognition results...': t.downloadingResults,
		'Processing results...': t.processingResults,
		'Finalizing transcription...': t.finalizingTranscription,
		'Updating ownCloud file index...': t.updatingIndex,
		'Sending notifications...': t.sendingNotifications,
		// Whisper statuses
		'Loading Whisper model...': t.loadingWhisperModel,
		'Transcribing with Whisper...': t.whisperTranscribing,
		'Processing Whisper results...': t.whisperProcessingResults
	};

	// Translate status message
	function translateStatus(status) {
		// Try exact match first
		if (statusTranslations[status]) {
			return statusTranslations[status];
		}

		// Try partial matches
		for (var key in statusTranslations) {
			if (status.indexOf(key.substring(0, 20)) !== -1) {
				return statusTranslations[key];
			}
		}

		return status;
	}

	var mimeTypes = [
		'audio/mpeg', 'audio/mp3', 'audio/wav', 'audio/x-wav',
		'audio/ogg', 'audio/opus', 'audio/mp4', 'audio/x-m4a',
		'audio/flac', 'audio/x-flac', 'audio/aac', 'audio/x-aac',
		'audio/wma', 'audio/x-ms-wma', 'audio/amr', 'audio/x-ape',
		'audio/ac3', 'audio/vnd.dolby.dd-raw', 'audio/alac',
		'audio/3gpp', 'audio/3gpp2',
		'video/mp4', 'video/x-m4v', 'video/webm',
		'video/mpeg', 'video/x-mpeg', 'video/avi', 'video/x-msvideo',
		'video/x-matroska', 'video/quicktime', 'video/x-flv',
		'video/3gpp', 'video/3gpp2', 'video/x-ms-wmv', 'video/x-ms-asf',
		'video/ogg', 'video/mp2t', 'video/MP2T',
		'video/vnd.dlna.mpeg-tts', 'video/dvd',
		'application/ogg', 'application/x-matroska'
	];

	var activeTasks = {};
	var allTasks = {};
	var lastStatus = {};
	var taskFilenames = {};
	var taskTimelines = {};
	var taskStartTimes = {};
	var expandedTasks = {};
	var statusBarCreated = false;
	var statusBarMinimized = false;

	var STORAGE_KEY = 'audio2text_tasks_' + OC.currentUser;

	function estimateCompletionTime(taskId) {
		if (!taskStartTimes[taskId] || !allTasks[taskId]) return null;

		var currentStatus = allTasks[taskId].status;

		// If waiting for Yandex results, show that it depends on their queue
		if (currentStatus && (
			currentStatus.indexOf('Waiting for results') >= 0 ||
			currentStatus.indexOf('Ожидание результатов') >= 0 ||
			currentStatus.indexOf('Processing results') >= 0 ||
			currentStatus.indexOf('Обработка результатов') >= 0
		)) {
			return '<span style="font-style: italic;">' + t.waitingForYandex + '</span>';
		}

		// For other stages, don't show time as it's unpredictable
		return null;
	}

	function estimateTotalTime() {
		var activeCount = Object.keys(activeTasks).length;

		if (activeCount === 0) {
			return '';
		}

		// Show that time depends on Yandex queue
		return '<span style="font-style: italic;">' + t.waitingForYandex + '</span>';
	}

	function saveTasks() {
		try {
			var tasksData = {
				allTasks: allTasks,
				taskFilenames: taskFilenames,
				taskTimelines: taskTimelines,
				taskStartTimes: taskStartTimes,
				lastUpdate: Date.now()
			};
			localStorage.setItem(STORAGE_KEY, JSON.stringify(tasksData));
		} catch(e) {
			console.error('[Audio2Text] Failed to save tasks:', e);
		}
	}

	function loadTasks() {
		try {
			var stored = localStorage.getItem(STORAGE_KEY);
			if (stored) {
				var tasksData = JSON.parse(stored);
				allTasks = tasksData.allTasks || {};
				taskFilenames = tasksData.taskFilenames || {};
				taskTimelines = tasksData.taskTimelines || {};
				taskStartTimes = tasksData.taskStartTimes || {};

				for (var taskId in allTasks) {
					if (allTasks[taskId].status === 'running') {
						var filename = taskFilenames[taskId];
						var sourceDir = allTasks[taskId].sourceDir || '/';

						activeTasks[taskId] = setInterval(function(tid, fn, dir) {
							return function() {
								checkTaskStatus(tid, fn, dir);
							};
						}(taskId, filename, sourceDir), 5000);

						lastStatus[taskId] = allTasks[taskId].lastStatus || t.processing;
					}
				}

				console.log('[Audio2Text] Loaded', Object.keys(allTasks).length, 'tasks from storage');
			}
		} catch(e) {
			console.error('[Audio2Text] Failed to load tasks:', e);
		}
	}

	function addTimelineEvent(taskId, event) {
		if (!taskTimelines[taskId]) {
			taskTimelines[taskId] = [];
		}

		var now = new Date();
		var timeStr = now.toLocaleTimeString(isRussian ? 'ru-RU' : 'en-US', {
			hour: '2-digit',
			minute: '2-digit',
			second: '2-digit'
		});

		taskTimelines[taskId].push({
			time: timeStr,
			event: event,
			timestamp: now.getTime()
		});

		saveTasks();
	}

	function createStatusBar() {
		if (statusBarCreated) return;
		statusBarCreated = true;

		var $statusBar = $('<div id="audio2text-status-bar">').css({
			position: 'fixed',
			top: '50px',
			left: '0',
			right: '0',
			backgroundColor: 'rgba(240, 240, 240, 0.95)',
			borderBottom: '2px solid #0082c9',
			padding: '8px 15px',
			zIndex: '9999',
			display: 'none',
			fontFamily: 'Arial, sans-serif',
			boxShadow: '0 2px 8px rgba(0,0,0,0.15)',
			transition: 'all 0.3s ease'
		});

		// Create yellow notification for minimized state
		var $yellowNotification = $('<div id="audio2text-yellow-notification">').css({
			display: 'none'
		});

		var $header = $('<div id="audio2text-header">').css({
			display: 'flex',
			justifyContent: 'space-between',
			alignItems: 'center',
			marginBottom: '8px',
			cursor: 'pointer'
		});


		var $title = $('<div id="audio2text-title">').css({
			fontWeight: 'bold',
			color: '#0082c9',
			fontSize: '13px'
		}).html(t.statusBarTitle);

		var $controls = $('<div>').css({
			display: 'flex',
			gap: '8px'
		});

		var $minimizeBtn = $('<button id="audio2text-minimize-btn">').css({
			background: 'none',
			border: '1px solid #ccc',
			borderRadius: '3px',
			padding: '2px 7px',
			cursor: 'pointer',
			fontSize: '11px'
		}).html(isRussian ? 'Скрыть' : 'Hide').attr('title', t.minimize);

		// Use click instead of on to avoid unload deprecation
		$minimizeBtn.get(0).addEventListener('click', function(e) {
			e.stopPropagation();
			toggleToYellowNotification();
		}, false);

		$controls.append($minimizeBtn);

		var $statsBtn = $('<button id="audio2text-stats-btn">').css({
			background: 'none',
			border: '1px solid #ccc',
			borderRadius: '3px',
			padding: '2px 7px',
			cursor: 'pointer',
			fontSize: '11px'
		}).html(isRussian ? '📊 Статистика' : '📊 Stats').attr('title', isRussian ? 'Показать статистику использования' : 'Show usage statistics');
		$statsBtn.get(0).addEventListener('click', function(e) {
			e.stopPropagation();
			showStats();
		}, false);
		$controls.append($statsBtn);
		$header.append($title).append($controls);

		var $taskList = $('<div id="audio2text-task-list">');

		$statusBar.append($header).append($taskList);
		$('body').prepend($statusBar);

		console.log('[Audio2Text] Status bar created');
	}

	function toggleToYellowNotification() {
		statusBarMinimized = !statusBarMinimized;

		if (statusBarMinimized) {
			// Hide full statusbar
			$('#audio2text-status-bar').fadeOut(200);

			// Show yellow notification with summary
			showYellowNotification();
		} else {
			// Hide yellow notification
			if (window.audio2textNotification) {
				window.audio2textNotification.remove();
				window.audio2textNotification = null;
			}

			// Show full statusbar
			$('#audio2text-status-bar').fadeIn(200);
		}
	}

	function showYellowNotification() {
		// Remove old notification if exists
		if (window.audio2textNotification && window.audio2textNotification.hide) {
			window.audio2textNotification.hide();
			window.audio2textNotification = null;
		}

		var completedActive = 0;
		var totalActive = Object.keys(activeTasks).length;
		var active = totalActive;

		for (var taskId in activeTasks) {
			if (activeTasks[taskId].status === 'completed' || activeTasks[taskId].status === 'failed') {
				completedActive++;
			}
		}

		var counterText = t.completedOf.replace('{completed}', completedActive).replace('{total}', totalActive);
		var summaryText = '🎤 ' + t.statusBarMinimized + ': ' + counterText;

		if (active > 0) {
			var timeInfo = estimateTotalTime();
			if (timeInfo) {
				summaryText += ' • ' + timeInfo;
			}
		}

		// Use OwnCloud system notification (like version 1)
		var htmlContent = summaryText +
			' <button id="audio2text-expand-from-notification" style="margin-left:10px;background:#fff;border:1px solid #ccc;border-radius:3px;padding:2px 8px;cursor:pointer;font-size:11px;">' +
			(isRussian ? 'Подробнее' : 'Details') + '</button>';

		if (OC.Notification && OC.Notification.showHtml) {
			window.audio2textNotification = OC.Notification.showHtml(htmlContent, {timeout: 0, isHTML: true});
		} else {
			window.audio2textNotification = OC.Notification.show(summaryText);
		}

		// Add click handler
		setTimeout(function() {
			var expandBtn = document.getElementById('audio2text-expand-from-notification');
			if (expandBtn) {
				expandBtn.addEventListener('click', function(e) {
					e.stopPropagation();
					toggleToYellowNotification();
				}, false);
			}
		}, 100);
	}

	function showStats() {
	var stats = {total: 0, completed: 0, processing: 0, failed: 0, cancelled: 0, totalDuration: 0};
	for (var taskId in allTasks) {
		var task = allTasks[taskId];
		stats.total++;
		if (task.status === 'completed') stats.completed++;
		else if (task.status === 'processing') stats.processing++;
		else if (task.status === 'failed') stats.failed++;
		else if (task.status === 'cancelled') stats.cancelled++;
		if (task.metadata && task.metadata.duration) {
			stats.totalDuration += parseFloat(task.metadata.duration);
		}
	}
	var hours = (stats.totalDuration / 3600).toFixed(2);
	var minutes = (stats.totalDuration / 60).toFixed(1);
	var estimatedCost = (stats.totalDuration / 60 * 1.2).toFixed(2);
	var message = isRussian ?
		'📊 Статистика:\\n\\nЗадач: ' + stats.total + '\\nЗавершено: ' + stats.completed + '\\nВ процессе: ' + stats.processing + '\\nОшибок: ' + stats.failed + '\\nОтменено: ' + stats.cancelled + '\\n\\nАудио: ' + hours + ' ч (' + minutes + ' мин)\\nСтоимость: ~' + estimatedCost + ' ₽\\n\\nТочный баланс:\\nhttps://console.cloud.yandex.ru/billing'
		:
		'📊 Statistics:\\n\\nTasks: ' + stats.total + '\\nCompleted: ' + stats.completed + '\\nProcessing: ' + stats.processing + '\\nFailed: ' + stats.failed + '\\nCancelled: ' + stats.cancelled + '\\n\\nAudio: ' + hours + ' h (' + minutes + ' min)\\nCost: ~' + estimatedCost + ' ₽\\n\\nBalance:\\nhttps://console.cloud.yandex.ru/billing';
	alert(message);
}
	function cancelTask(taskId) {
		var filename = taskFilenames[taskId] || 'this file';
		var confirmMsg = t.cancelConfirm.replace('{filename}', filename);

		if (confirm(confirmMsg)) {
			if (activeTasks[taskId]) {
				clearInterval(activeTasks[taskId]);
				delete activeTasks[taskId];
			}

			addTimelineEvent(taskId, t.taskCancelled);

			if (allTasks[taskId]) {
				allTasks[taskId].status = 'cancelled';
				allTasks[taskId].lastStatus = t.taskCancelled;
			}

			$.ajax({
				url: OC.generateUrl('/apps/audio2text/cancel/' + taskId),
				type: 'POST'
			});

			delete lastStatus[taskId];

			saveTasks();
			updateStatusBar();
		}
	}

	function toggleTaskDetails(taskId) {
		expandedTasks[taskId] = !expandedTasks[taskId];
		updateStatusBar();
	}

	function updateStatusBar() {
		var hasActiveTasks = Object.keys(activeTasks).length > 0;

		if (!hasActiveTasks) {
			$('#audio2text-status-bar').fadeOut();
			if (window.audio2textNotification) {
				window.audio2textNotification.remove();
				window.audio2textNotification = null;
			}
			return;
		}

		if (statusBarMinimized) {
			// Update yellow notification instead
			showYellowNotification();
			return;
		}

		// Show full statusbar
		$('#audio2text-status-bar').fadeIn();

		var $taskList = $('#audio2text-task-list');
		$taskList.empty();

		for (var taskId in activeTasks) {
			if (activeTasks.hasOwnProperty(taskId)) {
				var status = translateStatus(lastStatus[taskId] || t.processing);
				var filename = taskFilenames[taskId] || 'Unknown';
				var isExpanded = expandedTasks[taskId] || false;
				var estimatedTime = estimateCompletionTime(taskId);

				var $taskItem = $('<div>').css({
					padding: '6px',
					marginBottom: '4px',
					borderRadius: '3px',
					backgroundColor: 'rgba(255, 255, 255, 0.7)',
					border: '1px solid #ddd',
					cursor: 'pointer',
					transition: 'background-color 0.2s'
				}).attr('data-task-id', taskId);

				var $taskHeader = $('<div>').css({
					display: 'flex',
					justifyContent: 'space-between',
					alignItems: 'center'
				});

				var statusWithTime = status;
				if (estimatedTime) {
					statusWithTime += ' <span style="color: #888; font-size: 9px;">(' + estimatedTime + ')</span>';
				}

				var $taskInfo = $('<div>').css({
					flex: '1',
					fontSize: '11px'
				}).html('<strong>' + filename + ':</strong> <span style="color: #666;">' + statusWithTime + '</span>');

				var $taskControls = $('<div>').css({
					display: 'flex',
					gap: '6px'
				});

				var $detailsBtn = $('<button>').css({
					background: '#f5f5f5',
					border: '1px solid #bbb',
					borderRadius: '2px',
					padding: '2px 6px',
					cursor: 'pointer',
					fontSize: '9px',
					color: '#333'
				}).text(isExpanded ? t.hideDetails : t.showDetails);

				$detailsBtn.get(0).addEventListener('click', function(e) {
					e.stopPropagation();
					var tid = $(this).closest('[data-task-id]').attr('data-task-id');
					toggleTaskDetails(tid);
				}, false);

				var $cancelBtn = $('<button>').css({
					background: '#f44',
					border: 'none',
					borderRadius: '2px',
					padding: '2px 8px',
					cursor: 'pointer',
					fontSize: '9px',
					color: '#fff'
				}).text(t.cancel);

				$cancelBtn.get(0).addEventListener('click', function(e) {
					e.stopPropagation();
					var tid = $(this).closest('[data-task-id]').attr('data-task-id');
					cancelTask(tid);
				}, false);

				$taskControls.append($detailsBtn).append($cancelBtn);
				$taskHeader.append($taskInfo).append($taskControls);
				$taskItem.append($taskHeader);

				if (isExpanded && taskTimelines[taskId] && taskTimelines[taskId].length > 0) {
					var $timeline = $('<div>').css({
						marginTop: '8px',
						paddingTop: '8px',
						borderTop: '1px solid #ddd',
						fontSize: '10px'
					});

					var $timelineTitle = $('<div>').css({
						fontWeight: 'bold',
						marginBottom: '4px',
						color: '#555',
						fontSize: '10px'
					}).text(t.eventHistory);

					$timeline.append($timelineTitle);

					taskTimelines[taskId].forEach(function(entry) {
						var translatedEvent = translateStatus(entry.event);
						var $event = $('<div>').css({
							padding: '2px 0',
							color: '#444',
							fontSize: '10px'
						}).html('<span style="color: #0082c9; font-weight: bold;">' + entry.time + '</span> — ' + translatedEvent);
						$timeline.append($event);
					});

					$taskItem.append($timeline);
				}

				$taskItem.hover(
					function() { $(this).css('backgroundColor', 'rgba(255, 255, 255, 0.9)'); },
					function() { $(this).css('backgroundColor', 'rgba(255, 255, 255, 0.7)'); }
				);

				$taskItem.get(0).addEventListener('click', function() {
					var tid = $(this).attr('data-task-id');
					toggleTaskDetails(tid);
				}, false);

				$taskList.append($taskItem);
			}
		}
	}

	function logActivity(message, fileId, filePath) {
		$.ajax({
			url: OC.generateUrl('/apps/audio2text/activity'),
			type: 'POST',
			contentType: 'application/json',
			data: JSON.stringify({
				message: message,
				fileId: fileId,
				filePath: filePath
			})
		});
	}

	function loadPreferences(callback) {
		$.ajax({
			url: OC.generateUrl('/apps/audio2text/preferences'),
			type: 'GET',
			success: callback,
			error: function() {
				callback({
					language: 'ru-RU',
					model: $('#a2t-model').val() || 'general',
					engine: 'yandex',
					whisperModel: 'small',
					numbersAsWords: false,
					profanityFilter: true,
					createSubtitles: false
				});
			}
		});
	}

	function savePreferences(prefs, callback) {
		$.ajax({
			url: OC.generateUrl('/apps/audio2text/preferences'),
			type: 'POST',
			contentType: 'application/json',
			data: JSON.stringify(prefs),
			success: callback,
			error: callback
		});
	}

	function checkTaskStatus(taskId, filename, sourceDir) {
		$.ajax({
			url: OC.generateUrl('/apps/audio2text/status/' + taskId),
			type: 'GET',
			success: function(response) {
				if (response.status === 'completed') {
					addTimelineEvent(taskId, t.taskCompleted);

					var resultPath = sourceDir + '/' + filename.replace(/\.[^/.]+$/, '.txt');
					logActivity('Speech recognition completed for ' + filename, null, resultPath);

					if (allTasks[taskId]) {
						allTasks[taskId].status = 'completed';
						allTasks[taskId].lastStatus = t.taskCompleted;
					}

					setTimeout(function() {
						if (activeTasks[taskId]) {
							clearInterval(activeTasks[taskId]);
							delete activeTasks[taskId];
							delete lastStatus[taskId];
						}
						saveTasks();
						updateStatusBar();
					}, 3000);

					setTimeout(function() {
						if (OCA.Files && OCA.Files.App && OCA.Files.App.fileList) {
							OCA.Files.App.fileList.reload();
							setTimeout(function() {
								OCA.Files.App.fileList.reload();
							}, 2000);
						}
					}, 500);

					updateStatusBar();
				} else if (response.status === 'failed') {
					var errorMsg = response.error || 'Unknown error';
					addTimelineEvent(taskId, t.taskFailed.replace('{error}', errorMsg));

					if (allTasks[taskId]) {
						allTasks[taskId].status = 'failed';
						allTasks[taskId].lastStatus = t.taskFailed.replace('{error}', errorMsg);
					}

					if (activeTasks[taskId]) {
						clearInterval(activeTasks[taskId]);
						delete activeTasks[taskId];
						delete lastStatus[taskId];
					}

					saveTasks();
					updateStatusBar();
				} else if (response.status === 'running') {
					var progressMsg = response.progress || t.processing;

					if (lastStatus[taskId] !== progressMsg) {
						lastStatus[taskId] = progressMsg;
						addTimelineEvent(taskId, progressMsg);

						if (allTasks[taskId]) {
							allTasks[taskId].lastStatus = progressMsg;
						}

						saveTasks();
						updateStatusBar();
					}
				}
			},
			error: function() {
				if (activeTasks[taskId]) {
					clearInterval(activeTasks[taskId]);
					delete activeTasks[taskId];
					delete lastStatus[taskId];
				}
				updateStatusBar();
			}
		});
	}

	function startTranscription(filename, sourceDir, outputDir, settings) {
		logActivity('Started speech recognition for ' + filename + ' (engine: ' + (settings.engine || 'yandex') + ')', null, sourceDir + '/' + filename);

		$.ajax({
			url: OC.generateUrl('/apps/audio2text/transcribe'),
			type: 'POST',
			contentType: 'application/json',
			data: JSON.stringify({
				filename: filename,
				sourceDirectory: sourceDir,
				outputDirectory: outputDir,
				language: settings.language,
				model: settings.model,
				engine: settings.engine || 'yandex',
				whisperModel: settings.whisperModel || 'small',
				numbersAsWords: settings.numbersAsWords,
				profanityFilter: settings.profanityFilter,
				autoPunctuation: settings.autoPunctuation,
				createSubtitles: settings.createSubtitles
			}),
			success: function(response) {
				if (response.success && response.taskId) {
					var taskId = response.taskId;

					taskFilenames[taskId] = filename;
					lastStatus[taskId] = t.initializing;
					taskTimelines[taskId] = [];
					taskStartTimes[taskId] = Date.now();

					allTasks[taskId] = {
						status: 'running',
						lastStatus: t.initializing,
						sourceDir: sourceDir,
						outputDir: outputDir,
						engine: settings.engine || 'yandex'
					};

					addTimelineEvent(taskId, t.taskCreated);
					addTimelineEvent(taskId, t.initializing);

					createStatusBar();
					saveTasks();
					updateStatusBar();

					activeTasks[taskId] = setInterval(function() {
						checkTaskStatus(taskId, filename, sourceDir);
					}, 5000);

					setTimeout(function() {
						checkTaskStatus(taskId, filename, sourceDir);
					}, 1000);
				} else {
					alert(t.errorPrefix + (response.message || t.errorGeneric));
				}
			},
			error: function(xhr) {
				var msg = t.errorGeneric;
				try {
					var err = JSON.parse(xhr.responseText);
					if (err.error) msg = err.error;
				} catch(e) {}
				alert(t.errorPrefix + msg);
			}
		});
	}

	function updateDialogForEngine(engine) {
		if (engine === 'whisper') {
			$('#a2t-yandex-options').hide();
			$('#a2t-whisper-options').show();
			// Add auto-detect option to language if not present
			if ($('#a2t-language option[value="auto"]').length === 0) {
				$('#a2t-language').prepend($('<option value="auto">').text(t.languageAuto));
			}
		} else {
			$('#a2t-yandex-options').show();
			$('#a2t-whisper-options').hide();
			// Remove auto-detect option
			$('#a2t-language option[value="auto"]').remove();
		}
	}

	function showDialog(filename, context) {
		var dir = context.dir || '/';
		var selectedOutputDir = dir;

		loadPreferences(function(prefs) {
			if (prefs.defaultOutputDir) {
				selectedOutputDir = prefs.defaultOutputDir;
				$('#a2t-folder-display').text(selectedOutputDir);
			}
			var $dialog = $('<div id="audio2text-dialog">').css('padding', '15px');

			$dialog.append($('<p>').append($('<strong>').text(filename)));

			// Engine selector
			var $engineLabel = $('<label>').html('<strong>' + t.engine + '</strong>');
			var $engineSelect = $('<select id="a2t-engine">').css({width: '100%', padding: '5px', marginTop: '5px', marginBottom: '10px'});
			$engineSelect.append($('<option value="yandex">').text(t.engineYandex));
			$engineSelect.append($('<option value="whisper">').text(t.engineWhisper));
			$engineSelect.val(prefs.engine || 'yandex');
			$dialog.append($('<p>').append($engineLabel).append('<br>').append($engineSelect));

			// Language dropdown
			var $langLabel = $('<label>').text(t.language);
			var $langSelect = $('<select id="a2t-language">').css({width: '100%', padding: '5px', marginTop: '5px', marginBottom: '10px'});
			$langSelect.append($('<option value="ru-RU">').text(t.languageRussian));
			$langSelect.append($('<option value="en-US">').text(t.languageEnglish));
			$langSelect.append($('<option value="kk-KK">').text(t.languageKazakh));
			$langSelect.append($('<option value="tr-TR">').text(t.languageTurkish));
			$langSelect.append($('<option value="uz-UZ">').text(t.languageUzbek));
			$langSelect.append($('<option value="he-IL">').text(t.languageHebrew));
			$langSelect.append($('<option value="ar-AE">').text(t.languageArabic));
			$langSelect.append($('<option value="de-DE">').text(t.languageGerman));
			$langSelect.append($('<option value="es-ES">').text(t.languageSpanish));
			$langSelect.append($('<option value="fr-FR">').text(t.languageFrench));
			$langSelect.append($('<option value="it-IT">').text(t.languageItalian));
			$langSelect.append($('<option value="pt-BR">').text(t.languagePortuguese));
			$langSelect.append($('<option value="pl-PL">').text(t.languagePolish));
			$langSelect.append($('<option value="nl-NL">').text(t.languageDutch));
			$langSelect.append($('<option value="sv-SE">').text(t.languageSwedish));
			$langSelect.val(prefs.language || 'ru-RU');
			$dialog.append($('<p>').append($langLabel).append('<br>').append($langSelect));

			// Yandex-specific options (hidden when Whisper selected)
			var $yandexOptions = $('<div id="a2t-yandex-options">');

			var $modelLabel = $('<label>').html('<strong>' + (isRussian ? 'Модель (приоритет):' : 'Model (priority):') + '</strong>');
			var $modelSelect = $('<select id="a2t-model">').css({width: '100%', padding: '5px', marginTop: '5px', marginBottom: '10px'});
			$modelSelect.append($('<option value="general">').text('general - ' + (isRussian ? 'низкий приоритет, до 24ч' : 'low priority, up to 24h')));
			$modelSelect.append($('<option value="general:rc">').text('general:rc - ' + (isRussian ? 'средний приоритет, 1-2ч' : 'medium priority, 1-2h')));
			$modelSelect.val(prefs.model || 'general');
			$yandexOptions.append($('<p>').append($modelLabel).append('<br>').append($modelSelect));

			var $numbersCheck = $('<input type="checkbox" id="a2t-numbers">');
			if (prefs.numbersAsWords) $numbersCheck.prop('checked', true);
			$yandexOptions.append($('<p>').append($('<label>').append($numbersCheck).append(' ' + t.numbersAsWords)));

			var $profanityCheck = $('<input type="checkbox" id="a2t-profanity">');
			if (prefs.profanityFilter) $profanityCheck.prop('checked', true);
			$yandexOptions.append($('<p>').append($('<label>').append($profanityCheck).append(' ' + t.profanityFilter)));

			var $autoPunctuationCheck = $('<input type="checkbox" id="a2t-punctuation">');
			if (prefs.autoPunctuation) $autoPunctuationCheck.prop('checked', true);
			$yandexOptions.append($('<p>').append($('<label>').append($autoPunctuationCheck).append(' ' + t.autoPunctuation)));

			$dialog.append($yandexOptions);

			// Whisper-specific options (hidden by default)
			var $whisperOptions = $('<div id="a2t-whisper-options">').css('display', 'none');

			var $whisperModelLabel = $('<label>').html('<strong>' + t.whisperModel + '</strong>');
			var $whisperModelSelect = $('<select id="a2t-whisper-model">').css({width: '100%', padding: '5px', marginTop: '5px', marginBottom: '10px'});
			$whisperModelSelect.append($('<option value="tiny">').text('tiny - ' + (isRussian ? 'быстро, низкое качество' : 'fast, low quality')));
			$whisperModelSelect.append($('<option value="base">').text('base - ' + (isRussian ? 'быстро, среднее качество' : 'fast, medium quality')));
			$whisperModelSelect.append($('<option value="small">').text('small - ' + (isRussian ? 'средняя скорость, хорошее качество' : 'moderate speed, good quality')));
			$whisperModelSelect.append($('<option value="medium">').text('medium - ' + (isRussian ? 'медленно, высокое качество' : 'slow, high quality')));
			$whisperModelSelect.val(prefs.whisperModel || 'small');
			$whisperOptions.append($('<p>').append($whisperModelLabel).append('<br>').append($whisperModelSelect));

			var $whisperNote = $('<p>').css({fontSize: '0.85em', color: '#e67e22', marginBottom: '10px'}).text(t.whisperNote);
			$whisperOptions.append($whisperNote);

			$dialog.append($whisperOptions);

			// Subtitles (common for both engines)
			var $subtitlesCheck = $('<input type="checkbox" id="a2t-subtitles">');
			if (prefs.createSubtitles) $subtitlesCheck.prop('checked', true);
			$dialog.append($('<p>').append($('<label>').append($subtitlesCheck).append(' ' + t.createSubtitles)));

			// Output folder
			var $folderRow = $('<p>').css('marginBottom', '10px');
			var $folderLabel = $('<label>').text(t.saveToFolder).css('display', 'block');
			var $folderDisplay = $('<strong id="a2t-folder-display">').text(selectedOutputDir);
			var $folderBtn = $('<button>').text(t.chooseFolder).css({
				marginLeft: '10px',
				padding: '5px 10px'
			});

			$folderBtn.get(0).addEventListener('click', function(e) {
				e.preventDefault();
				OC.dialogs.filepicker(
					t.chooseFolderTitle,
					function(path) {
						selectedOutputDir = path;
						$('#a2t-folder-display').text(path);
					},
					false,
					'httpd/unix-directory',
					true
				);
			}, false);

			$folderRow.append($folderLabel).append($folderDisplay).append($folderBtn);

			var $saveDefaultCheck = $('<input type="checkbox" id="a2t-save-default-folder">');
			var $saveDefaultLabel = $('<label>').css({display: 'block', marginTop: '5px', fontSize: '0.9em', color: '#666'});
			$saveDefaultLabel.append($saveDefaultCheck).append(' ' + (isRussian ? 'Сохранить эту папку по умолчанию' : 'Save this folder as default'));
			$folderRow.append($saveDefaultLabel);
			$dialog.append($folderRow);

			$('body').append($dialog);

			// Engine change handler
			$engineSelect.get(0).addEventListener('change', function() {
				updateDialogForEngine(this.value);
			}, false);

			// Apply initial engine state
			updateDialogForEngine(prefs.engine || 'yandex');

			$dialog.dialog({
				title: t.dialogTitle,
				modal: true,
				width: 450,
				buttons: [
					{
						text: t.cancelBtn,
						click: function() {
							$(this).dialog('close');
						}
					},
					{
						text: t.startBtn,
						click: function() {
							var selectedEngine = $('#a2t-engine').val();
							var settings = {
								language: $('#a2t-language').val(),
								engine: selectedEngine,
								model: $('#a2t-model').val() || 'general',
								whisperModel: $('#a2t-whisper-model').val() || 'small',
								numbersAsWords: $('#a2t-numbers').is(':checked'),
								profanityFilter: $('#a2t-profanity').is(':checked'),
								autoPunctuation: $('#a2t-punctuation').is(':checked'),
								createSubtitles: $('#a2t-subtitles').is(':checked')
							};
							if ($('#a2t-save-default-folder').is(':checked')) {
								settings.defaultOutputDir = selectedOutputDir;
							}

							$(this).dialog('close');

							savePreferences(settings, function() {
								startTranscription(filename, dir, selectedOutputDir, settings);
							});
						}
					}
				],
				close: function() {
					$(this).remove();
				}
			});
		});
	}

	function startBulkRecognition() {
		if (!OCA.Files || !OCA.Files.App || !OCA.Files.App.fileList) {
			alert(t.filesListUnavailable);
			return;
		}

		var selectedFiles = OCA.Files.App.fileList.getSelectedFiles();

		if (selectedFiles.length === 0) {
			alert(t.noFiles);
			return;
		}

		var mediaFiles = selectedFiles.filter(function(file) {
			var mime = file.mimetype || '';
			return mimeTypes.indexOf(mime) !== -1 && !file.name.toLowerCase().endsWith('.opus');
		});

		if (mediaFiles.length === 0) {
			alert(t.noMedia);
			return;
		}

		loadPreferences(function(prefs) {
			var dir = OCA.Files.App.fileList.getCurrentDirectory();

			OC.dialogs.confirm(
				t.bulkConfirm.replace('{count}', mediaFiles.length),
				t.bulkTitle,
				function(confirmed) {
					if (confirmed) {
						mediaFiles.forEach(function(file) {
							startTranscription(file.name, dir, dir, {
								language: prefs.language || 'ru-RU',
								engine: prefs.engine || 'yandex',
								model: $('#a2t-model').val() || 'general',
								whisperModel: prefs.whisperModel || 'small',
								numbersAsWords: prefs.numbersAsWords || false,
								profanityFilter: prefs.profanityFilter !== false,
								createSubtitles: prefs.createSubtitles || false
							});
						});
					}
				}
			);
		});
	}

	function addBulkRecognitionButton() {
		if (!OCA.Files || !OCA.Files.App) {
			console.log('[Audio2Text] Files app not ready, retrying...');
			setTimeout(addBulkRecognitionButton, 1000);
			return;
		}

		if ($('#audio2text-bulk-btn').length > 0) {
			console.log('[Audio2Text] Bulk button already exists');
			return;
		}

		// Find the download button's parent container
		var $toolbar = $('#selectedActionsList');
		if ($toolbar.length === 0) {
			console.log('[Audio2Text] Toolbar #selectedActionsList not found, retrying...');
			setTimeout(addBulkRecognitionButton, 1500);
			return;
		}

		var $bulkBtn = $('<a id="audio2text-bulk-btn">').css({
			display: 'inline-block',
			marginLeft: '10px',
			cursor: 'pointer'
		}).html('<span class="icon icon-audio"></span><span>' + t.bulkButton + '</span>');

		$bulkBtn.get(0).addEventListener('click', function(e) {
			e.preventDefault();
			e.stopPropagation();
			startBulkRecognition();
		}, false);

		$toolbar.append($bulkBtn);
		console.log('[Audio2Text] Bulk button added to:', $toolbar.attr('id'));

		function updateBulkButton() {
			if (!OCA.Files || !OCA.Files.App || !OCA.Files.App.fileList) return;

			var selectedFiles = OCA.Files.App.fileList.getSelectedFiles();
			var hasMedia = selectedFiles.some(function(file) {
				var mime = file.mimetype || '';
				return mimeTypes.indexOf(mime) !== -1;
			});

			var $btn = $('#audio2text-bulk-btn');
			if (hasMedia && selectedFiles.length > 0) {
				$btn.css('display', 'inline-block');
			} else {
				$btn.css('display', 'none');
			}
		}

		setInterval(updateBulkButton, 500);
	}

	function registerActions() {
		if (!OCA.Files || !OCA.Files.fileActions) {
			return;
		}

		mimeTypes.forEach(function(mimeType) {
			OCA.Files.fileActions.registerAction({
				name: 'SpeechRecognition',
				displayName: t.recognizeSpeech,
				mime: mimeType,
				permissions: OC.PERMISSION_READ,
				icon: OC.imagePath('audio2text', 'microphone'),
				actionHandler: function(filename, context) {
					if (filename.toLowerCase().endsWith('.opus')) {
						alert(t.cannotProcessOpus);
						return;
					}
					showDialog(filename, context);
				}
			});
		});

		console.log('[Audio2Text] Registered', mimeTypes.length, 'MIME types');
	}

	$(document).ready(function() {
		loadTasks();

		if (OCA.Files && OCA.Files.fileActions) {
			registerActions();
		} else {
			setTimeout(registerActions, 1000);
		}

		// Temporarily disabled to fix checkbox selection issue
		// setTimeout(addBulkRecognitionButton, 2000);
		createStatusBar();

		if (Object.keys(allTasks).length > 0) {
			updateStatusBar();
		}
	});

})();
