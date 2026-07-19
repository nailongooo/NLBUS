if (!getToken()) {
  window.location.href = "index.html";
}

const sections = ["overview", "pending", "import", "announcement", "logs"];

function showSection(name) {
  sections.forEach(s => {
    document.getElementById("section-" + s).style.display = s === name ? "block" : "none";
  });
  document.querySelectorAll(".sidebar a").forEach(a => a.classList.remove("active"));
  document.getElementById("nav-" + name).classList.add("active");

  if (name === "overview") loadStats();
  if (name === "pending") loadPendingRoutes();
  if (name === "logs") loadLogs();
}

document.getElementById("logoutBtn").addEventListener("click", () => {
  clearToken();
  window.location.href = "index.html";
});

sections.forEach(s => {
  document.getElementById("nav-" + s).addEventListener("click", () => showSection(s));
});

async function loadStats() {
  try {
    const stats = await apiRequest("/admin/stats");
    document.getElementById("statTotalRoutes").textContent = stats.total_routes;
    document.getElementById("statPendingRoutes").textContent = stats.pending_routes;
    document.getElementById("statTotalFeedback").textContent = stats.total_feedback;
  } catch (err) {
    alert(err.message);
  }
}

async function loadPendingRoutes() {
  const tbody = document.getElementById("pendingTableBody");
  tbody.innerHTML = "<tr><td colspan='4'>加载中...</td></tr>";
  try {
    const routes = await apiRequest("/admin/routes/pending");
    if (routes.length === 0) {
      tbody.innerHTML = "<tr><td colspan='4'>暂时没有待审核的路线</td></tr>";
      return;
    }
    tbody.innerHTML = routes.map(r => `
      <tr>
        <td>${escapeHtml(r.name)}</td>
        <td>${escapeHtml(r.direction || "-")}</td>
        <td>${r.stops.length} 个站点</td>
        <td>
          <button class="btn-sm btn-approve" onclick="approveRoute('${r.id}')">通过</button>
          <button class="btn-sm btn-reject" onclick="rejectRoute('${r.id}')">驳回</button>
          <button class="btn-sm btn-secondary" onclick="deleteRoute('${r.id}')">删除</button>
        </td>
      </tr>
    `).join("");
  } catch (err) {
    tbody.innerHTML = `<tr><td colspan='4'>加载失败：${err.message}</td></tr>`;
  }
}

async function approveRoute(id) {
  try {
    await apiRequest(`/admin/routes/${id}/approve`, { method: "POST" });
    loadPendingRoutes();
    loadStats();
  } catch (err) { alert(err.message); }
}

async function rejectRoute(id) {
  try {
    await apiRequest(`/admin/routes/${id}/reject`, { method: "POST" });
    loadPendingRoutes();
    loadStats();
  } catch (err) { alert(err.message); }
}

async function deleteRoute(id) {
  if (!confirm("确定要删除这条路线吗？此操作不可撤销。")) return;
  try {
    await apiRequest(`/admin/routes/${id}`, { method: "DELETE" });
    loadPendingRoutes();
    loadStats();
  } catch (err) { alert(err.message); }
}

// ---- 导入 ----
document.getElementById("csvImportForm").addEventListener("submit", async (e) => {
  e.preventDefault();
  const file = document.getElementById("csvFile").files[0];
  const resultEl = document.getElementById("csvImportResult");
  if (!file) return;
  const formData = new FormData();
  formData.append("file", file);
  try {
    const data = await apiRequest("/admin/import/csv", { method: "POST", body: formData });
    resultEl.textContent = `成功导入 ${data.imported} 条路线`;
  } catch (err) {
    resultEl.textContent = "导入失败：" + err.message;
  }
});

document.getElementById("jsonImportForm").addEventListener("submit", async (e) => {
  e.preventDefault();
  const file = document.getElementById("jsonFile").files[0];
  const resultEl = document.getElementById("jsonImportResult");
  if (!file) return;
  const formData = new FormData();
  formData.append("file", file);
  try {
    const data = await apiRequest("/admin/import/json", { method: "POST", body: formData });
    resultEl.textContent = `成功导入 ${data.imported} 条路线`;
  } catch (err) {
    resultEl.textContent = "导入失败：" + err.message;
  }
});

document.getElementById("gtfsImportForm").addEventListener("submit", async (e) => {
  e.preventDefault();
  const resultEl = document.getElementById("gtfsImportResult");
  const formData = new FormData();
  formData.append("routes", document.getElementById("gtfsRoutes").files[0]);
  formData.append("stops", document.getElementById("gtfsStops").files[0]);
  formData.append("trips", document.getElementById("gtfsTrips").files[0]);
  formData.append("stop_times", document.getElementById("gtfsStopTimes").files[0]);
  try {
    const data = await apiRequest("/admin/import/gtfs", { method: "POST", body: formData });
    resultEl.textContent = `解析出 ${data.parsed} 条路线，成功导入 ${data.imported} 条`;
  } catch (err) {
    resultEl.textContent = "导入失败：" + err.message;
  }
});

// ---- 公告 ----
document.getElementById("announcementForm").addEventListener("submit", async (e) => {
  e.preventDefault();
  const title = document.getElementById("annTitle").value;
  const content = document.getElementById("annContent").value;
  const isPinned = document.getElementById("annPinned").checked;
  const resultEl = document.getElementById("announcementResult");
  try {
    await apiRequest("/admin/announcements", {
      method: "POST",
      body: JSON.stringify({ title, content, is_pinned: isPinned })
    });
    resultEl.textContent = "发布成功";
    e.target.reset();
  } catch (err) {
    resultEl.textContent = "发布失败：" + err.message;
  }
});

// ---- 日志 ----
async function loadLogs() {
  const logBox = document.getElementById("logBox");
  logBox.textContent = "加载中...";
  try {
    const data = await apiRequest("/admin/logs");
    logBox.textContent = data.lines.join("\n") || "暂无日志";
  } catch (err) {
    logBox.textContent = "加载失败：" + err.message;
  }
}

function escapeHtml(str) {
  return String(str).replace(/[&<>"']/g, m => ({
    "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;"
  }[m]));
}

showSection("overview");
