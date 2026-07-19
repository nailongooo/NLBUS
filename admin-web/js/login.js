document.getElementById("loginForm").addEventListener("submit", async (e) => {
  e.preventDefault();
  const username = document.getElementById("username").value.trim();
  const password = document.getElementById("password").value;
  const errorEl = document.getElementById("errorText");
  errorEl.textContent = "";

  try {
    const data = await apiRequest("/admin/login", {
      method: "POST",
      body: JSON.stringify({ username, password })
    });
    setToken(data.token);
    window.location.href = "dashboard.html";
  } catch (err) {
    errorEl.textContent = err.message;
  }
});
