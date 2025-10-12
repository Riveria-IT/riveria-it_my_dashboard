<?php
require __DIR__ . '/config.php';

header('Content-Type: application/json; charset=utf-8');
if ($_SERVER['REQUEST_METHOD'] !== 'GET') {
  http_response_code(405); echo json_encode(['error'=>'Method not allowed']); exit;
}

$clientId = isset($_GET['clientId']) ? preg_replace('/[^a-zA-Z0-9_\-]/','', $_GET['clientId']) : '';
if ($clientId === '') {
  http_response_code(400); echo json_encode(['error'=>'clientId missing']); exit;
}

$file = $DATA_DIR . "/$clientId.json";
if (!file_exists($file)) {
  echo json_encode(['exists'=>false, 'data'=>null]); exit;
}

$payload = file_get_contents($file);
echo json_encode(['exists'=>true, 'data'=>json_decode($payload, true)], JSON_UNESCAPED_UNICODE);