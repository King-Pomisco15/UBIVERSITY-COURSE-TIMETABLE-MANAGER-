<?php
header("Content-Type: application/json");

// POST only
if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    http_response_code(405);
    die(json_encode(['success' => false, 'error' => ['code' => 'METHOD_NOT_ALLOWED', 'message' => 'Method not allowed']]));
}

session_start();
$_SESSION = [];
session_destroy();

// Expire the session cookie in the browser too
setcookie(session_name(), '', time() - 3600, '/');

http_response_code(200);
echo json_encode(['success' => true]);