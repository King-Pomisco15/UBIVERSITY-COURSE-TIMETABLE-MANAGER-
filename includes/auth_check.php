<?php
$timeout = 30 * 60;   // 30 minutes of inactivity, in seconds

ini_set('session.gc_maxlifetime', $timeout);
session_start();

// 1. Not logged in?
if (!isset($_SESSION['user_id'])) {
    http_response_code(401);
    die(json_encode(['success' => false, 'error' => ['code' => 'NOT_LOGGED_IN', 'message' => 'Not logged in']]));
}

// 2. Idle for too long?
if (!isset($_SESSION['last_activity']) || time() - $_SESSION['last_activity'] > $timeout) {
    $_SESSION = [];
    session_destroy();
    http_response_code(401);
    die(json_encode(['success' => false, 'error' => ['code' => 'SESSION_EXPIRED', 'message' => 'Session expired, please log in again']]));
}

// 3. Still active: reset the clock
$_SESSION['last_activity'] = time();