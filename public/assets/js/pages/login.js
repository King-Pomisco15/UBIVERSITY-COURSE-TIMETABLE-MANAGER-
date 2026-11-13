const form = document.getElementById('loginForm');
const msg = document.getElementById('message');

form.addEventListener('submit', async (e) => {
  e.preventDefault();   // stops the page reloading

  const res = await fetch('/timetable-manager/api/login.php', {
    method: 'POST',
    headers: {'Content-Type': 'application/json'},
    body: JSON.stringify({
      email: document.getElementById('email').value,
      password: document.getElementById('password').value
    })
  });
  const json = await res.json();

  if (json.success) {
    window.location.href = 'dashboard.html';   
  } else {
    msg.textContent = json.error.message;
  }
});