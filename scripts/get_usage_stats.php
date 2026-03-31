<?php
$statusDir = '/home/www/drive/data/audio2text_tmp';
$stats = array('total_files' => 0, 'total_duration' => 0, 'completed' => 0, 'failed' => 0, 'processing' => 0, 'cancelled' => 0);

if (is_dir($statusDir)) {
    $files = glob($statusDir . '/*.status');
    if ($files) {
        foreach ($files as $file) {
            $content = @file_get_contents($file);
            if ($content) {
                $data = json_decode($content, true);
                if ($data) {
                    $stats['total_files']++;
                    $status = isset($data['status']) ? $data['status'] : 'unknown';
                    if (isset($stats[$status])) { $stats[$status]++; }
                    if (isset($data['metadata']['duration'])) {
                        $stats['total_duration'] += floatval($data['metadata']['duration']);
                    }
                }
            }
        }
    }
}

$minutes = $stats['total_duration'] / 60;
$hours = $stats['total_duration'] / 3600;
$cost = round($minutes * 1.2, 2);

header('Content-Type: application/json');
echo json_encode(array(
    'success' => true,
    'stats' => $stats,
    'summary' => array(
        'total_hours' => round($hours, 2),
        'total_minutes' => round($minutes, 2),
        'estimated_cost_rub' => $cost,
        'note_ru' => 'Точный баланс: https://console.cloud.yandex.ru/billing',
        'note_en' => 'Exact balance: https://console.cloud.yandex.ru/billing'
    )
));
?>
