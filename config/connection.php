<?php
$servername = "localhost";
$username = "root";
$password = "";
$dbname = "timetable_manager";

$conn = new mysqli($servername, $username, $password, $dbname);

if ($conn->connect_error) {
    error_log($conn->connect_error);
    http_response_code(500);
    die(json_encode(['success' => false, 'error' => ['code' => 'DB_ERROR', 'message' => 'Database unavailable']]));
}

$conn->set_charset("utf8mb4");