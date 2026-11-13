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
$email = trim($data['email'] ?? '');
$password = $data['password'] ?? ''; 

// empty fields 
if ($email === "" || $password === "") {
  http_response_code(400);
  die(json_encode(['success' => false, 'error' => ['code' => 'MISSING_FIELDS', 'message' => 'Missing required fields']]));
}

// Password lookup
$stmt = $conn->prepare("SELECT id, full_name, email, password_hash, role, is_active FROM users WHERE email = ?");


// Check if the statement was prepared successfully

if (!$stmt) {
    error_log("Failed to prepare statement: " . $conn->error);
    http_response_code(500);
    die(json_encode(['success' => false, 'error' => ['code' => 'INTERNAL_ERROR', 'message' => 'Internal server error']]));
}

// Execute the statement and fetch the user data
$stmt->bind_param("s", $email);
$stmt->execute();
$result = $stmt->get_result();
$user = $result->fetch_assoc();   // one row, or null if no match
$stmt->close();

// We don't reveal whether the email exists or not, to avoid giving hints to attackers. We just say "invalid credentials" for both cases. In short, wrong password and non-existent email are treated the same way.
// But wrong password sha
if (!$user || !password_verify($password, $user["password_hash"])) {
 http_response_code(401);
 die(json_encode(["success"=> false,
 "error"=> ["code"=> "INVALID_CREDENTIALS", "message"=> "Invalid email or password"]]));
}

// Check if the account is active
if ((int)$user["is_active"] === 0) {
  http_response_code(403);
  die(json_encode(["success"=> false,
 "error"=> ["code"=> "ACCOUNT_INACTIVE", "message"=> "Account is inactive"]]));
}

// Start a session and store user information in session variables
session_start(); 
session_regenerate_id(true);
$_SESSION['user_id'] = $user['id'];
$_SESSION['role'] = $user['role'];
$_SESSION['last_activity'] = time();  // Store the current timestamp for session timeout tracking

http_response_code(200);
echo json_encode(['success'=> true,'data'=> ['id' => $user['id'],
'full_name' => $user['full_name'],
'email' => $user['email'],
'role' => $user['role'],
]]);

/**
 * Almost made an error 
*$hash = password_hash($password, PASSWORD_DEFAULT);
*$correct = password_verify($password, $hash);
 */