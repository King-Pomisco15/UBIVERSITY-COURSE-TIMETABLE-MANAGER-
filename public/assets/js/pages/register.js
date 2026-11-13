const form = document.getElementById('registerForm');
const msg = document.getElementById('message');

form.addEventListener('submit', async (e) => {
  e.preventDefault();

  const res = await fetch('/timetable-manager/api/register.php', {
    method: 'POST',
    headers: {'Content-Type': 'application/json'},
    body: JSON.stringify({
      full_name: document.getElementById('full_name').value,
      email: document.getElementById('email').value,
      password: document.getElementById('password').value
    })
  });
  const json = await res.json();

  if (json.success) {
    msg.textContent = 'Account created! Redirecting to login...';
    setTimeout(() => { window.location.href = 'login.html'; }, 1500);
  } else {
    msg.textContent = json.error.message;
  }
});