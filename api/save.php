<?php
require __DIR__ . '/config.php';

header('Content-Type: application/json; charset=utf-8');
if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
  http_response_code(405); echo json_encode(['error'=>'Method not allowed']); exit;
}

$body = file_get_contents('php://input');
$in = json_decode($body, true);
if (!$in || !isset($in['clientId']) || !isset($in['data'])) {
  http_response_code(400); echo json_encode(['error'=>'invalid payload']); exit;
}

$clientId = preg_replace('/[^a-zA-Z0-9_\-]/','', $in['clientId']);
if ($clientId === '') { http_response_code(400); echo json_encode(['error'=>'invalid clientId']); exit; }

$file = $DATA_DIR . "/$clientId.json";
$tmp  = $file . '.tmp';

$ok = file_put_contents($tmp, json_encode($in['data'], JSON_UNESCAPED_UNICODE|JSON_PRETTY_PRINT), LOCK_EX);
if ($ok === false) { http_response_code(500); echo json_encode(['error'=>'write failed']); exit; }

if (!rename($tmp, $file)) { @unlink($tmp); http_response_code(500); echo json_encode(['error'=>'atomic rename failed']); exit; }

echo json_encode(['ok'=>true]);