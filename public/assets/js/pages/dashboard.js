async function init() {
  const res = await fetch('/timetable-manager/api/me.php');
  const json = await res.json();

  if (!json.success) {
    window.location.href = 'login.html';   // not logged in, so where?
    return;
  }
  document.getElementById('welcome').textContent = 'Welcome, ' + json.data.full_name;
}

document.getElementById('logoutBtn').addEventListener('click', async () => {
  await fetch('/timetable-manager/api/logout.php', { method: 'POST' });
  window.location.href = 'login.html';
});

init();