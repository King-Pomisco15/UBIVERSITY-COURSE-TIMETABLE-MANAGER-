<?php 
header ("Content-Type: application/json");
require "../config/connection.php";

// Check if the request method is POST, reject if anything else
if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    http_response_code(405);
    die(json_encode(['success' => false, 'error' => ['code' => 'METHOD_NOT_ALLOWED', 'message' => 'Method not allowed']]));
}

// Parse the JSON data from the request body
$data = json_decode(file_get_contents('php://input'), true);
   // Silent failure handling for JSON parsing errors
   if (!is_array($data)) {
       http_response_code(400);
       die(json_encode(['success' => false, 'error' => ['code' => 'INVALID_JSON', 'message' => 'Invalid request body']]));
   }

   // Validate the required fields
$full_name = trim($data['full_name'] ?? '');
$email = trim($data['email'] ?? '');
$password = $data['password'] ?? ''; 

//name, email, & password validation
if (empty($full_name) || empty($email) || empty($password)) {
    http_response_code(400);
    die(json_encode(['success' => false, 'error' => ['code' => 'MISSING_FIELDS', 'message' => 'Missing required fields']]));
}

// Validate email format and password strength
if (!filter_var ($email, FILTER_VALIDATE_EMAIL)) {
    http_response_code(400);
    die(json_encode(['success' => false, 'error' => ['code' => 'INVALID_EMAIL', 'message' => 'Invalid email format']]));
}

// Validate password length
if (strlen($password) < 8) {
    http_response_code(400);
    die(json_encode(['success' => false, 'error' => ['code' => 'WEAK_PASSWORD', 'message' => 'Password must be at least 8 characters long']]));
}

// Check if the email already exists
$stmt = $conn->prepare("SELECT id FROM users WHERE email = ?");
if (!$stmt) {
    error_log($conn->error);
    http_response_code(500);
    die(json_encode(['success' => false, 'error' => ['code' => 'SERVER_ERROR', 'message' => 'Something went wrong']]));
}
$stmt->bind_param("s", $email);
$stmt->execute();
$result = $stmt->get_result();
if ($result->num_rows > 0) {
    http_response_code(409);
    die(json_encode(['success' => false, 'error' => ['code' => 'EMAIL_EXISTS', 'message' => 'Email already exists']]));
}
$stmt->close();

// Hash and insert
$hash = password_hash($password, PASSWORD_DEFAULT);

$stmt = $conn->prepare("INSERT INTO users (full_name, email, password_hash) VALUES (?, ?, ?)");
if (!$stmt) {
    error_log($conn->error);
    http_response_code(500);
    die(json_encode(['success' => false, 'error' => ['code' => 'SERVER_ERROR', 'message' => 'Something went wrong']]));
}
$stmt->bind_param("sss", $full_name, $email, $hash);

if ($stmt->execute()) {
    http_response_code(201);
    echo json_encode(['success' => true, 'data' => ['id' => $conn->insert_id]]);
} else {
    error_log($stmt->error);
    http_response_code(500);
    echo json_encode(['success' => false, 'error' => ['code' => 'SERVER_ERROR', 'message' => 'Something went wrong']]);
}
$stmt->close();