<?php 
header ("Content-Type: application/json");
require "../config/connection.php";

if ($_SERVER['REQUEST_METHOD'] !== 'GET') {
    http_response_code(405);
    die(json_encode(['success' => false, 'error' => ['code' => 'METHOD_NOT_ALLOWED', 'message' => 'Method not allowed']]));
}

REQUIRE "../includes/auth_check.php";  // This will handle session validation and user authentication

// 4. Find the user by id from the session
$stmt = $conn->prepare("SELECT id, full_name, email, role FROM users WHERE id = ? AND is_active = 1");

// Check if the statement was prepared successfully
if (!$stmt) {
    error_log("Failed to prepare statement: " . $conn->error);
    http_response_code(500);
    die(json_encode(['success' => false, 'error' => ['code' => 'INTERNAL_ERROR', 'message' => 'Internal server error']]));
}

// Bind the user ID from the session to the prepared statement
$stmt->bind_param("i", $_SESSION['user_id']);   // "i" = integer
$stmt->execute();
$user = $stmt->get_result()->fetch_assoc();
$stmt->close();

// closes the session if the user is not found or inactive
if (!$user) {
  session_destroy();
  http_response_code(401);
  die(json_encode(["success"=> false,"error"=> ["code"=> "NOT_LOGGED_IN","message"=> "NOT LOGGED IN"]]));
}

// login successful, return user data
http_response_code(200);
echo json_encode(['success' => true, 'data' => $user]);
