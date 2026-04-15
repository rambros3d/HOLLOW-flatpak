"""
Hollow relay capacity calculator — PySide6 UI.

Excel-style table where you can add/remove server rows and see the computed
per-box concurrent user capacity, bottleneck, per-user cost, and monthly
traffic. Sort any column by clicking its header. Save / load your comparison
list as JSON.

All numbers use measurements from the 2026-04-15 load tests plus the planned
Phase 7 optimizations (TCP buffer tuning, permessage-deflate, binary framing).

Run:
    python capacity_ui.py
"""

from __future__ import annotations

import json
import sys
from dataclasses import dataclass
from pathlib import Path

from PySide6.QtCore import Qt
from PySide6.QtGui import QColor
from PySide6.QtWidgets import (
    QApplication,
    QCheckBox,
    QComboBox,
    QDoubleSpinBox,
    QFileDialog,
    QFormLayout,
    QGroupBox,
    QHBoxLayout,
    QHeaderView,
    QLabel,
    QLineEdit,
    QMainWindow,
    QMessageBox,
    QPushButton,
    QSpinBox,
    QTableWidget,
    QTableWidgetItem,
    QVBoxLayout,
    QWidget,
)

# ---------------------------------------------------------------------------
# Measured constants (see HOLLOW_PLAN.md Phase 7, loadtest_results/*.csv)
# ---------------------------------------------------------------------------

# RAM per connection. Measured on OVH 8 GB VPS 2026-04-15.
RAM_KB_PER_CONN_BASELINE = 133        # native TLS, current relay code
RAM_KB_PER_CONN_OPTIMIZED = 30        # after TCP buffer cap to 16KB + bounded mpsc
# Nginx adds ~53 KB per conn on top of the relay's own cost.
RAM_KB_PER_CONN_NGINX_OVERHEAD = 53

# Bandwidth per conn (B/sec, sustained 24/7 average).
# Baseline = raw JSON WS traffic.
# Optimized idle = permessage-deflate compressed heartbeat (~3x reduction).
# Realistic = 10% users actively chatting, fanning out to ~30 room-mates.
BW_BYTES_PER_CONN_BASELINE_IDLE = 50
BW_BYTES_PER_CONN_OPTIMIZED_IDLE = 17
BW_BYTES_PER_CONN_BASELINE_REALISTIC = 100
BW_BYTES_PER_CONN_OPTIMIZED_REALISTIC = 33

# CPU auths/sec per thread.
# Measured 2026-04-15 on AMD EPYC Genoa 4-thread VPS: 800 auths/sec/thread
# at p99 < 10ms (3200/sec on 4 threads, 0 failures).
#
# We use CONSERVATIVE 500 auths/sec/thread — covers any CPU from ~2015 onward
# (old Haswell Xeons, early Ryzens, and everything newer). Modern CPUs are
# ~60% faster but CPU is never the bottleneck for realistic chat-app scaling,
# so false precision from CPU-type dropdowns doesn't help.
CPU_AUTHS_PER_THREAD_CONSERVATIVE = 500

# OS reserve (don't spend this on conns).
OS_RESERVE_GB = 1

# Reconnect rate per concurrent user per second (realistic churn).
# 0.05% / sec = user reconnects every ~33 minutes on average.
RECONNECT_RATE_PER_SEC = 0.0005

# Fraction of CPU budget we're willing to spend on auth churn before calling
# the box "CPU-bound" (leaves headroom for message fanout + heartbeats).
CPU_HEADROOM = 0.5

# Peak concurrency vs registered users — at scale, ~25% of registered users
# are online simultaneously at peak.
PEAK_CONCURRENCY = 0.25


@dataclass
class Server:
    name: str = "New Server"
    ram_gb: float = 64.0
    bw_gbps: float = 1.0
    cores: int = 8
    threads: int = 16
    price_usd_mo: float = 50.0
    setup_usd: float = 0.0
    traffic_tb_cap: float = 0.0          # 0 = unmetered
    overage_per_tb_usd: float = 1.0
    nginx: bool = False                   # if True, add Nginx overhead to per-conn cost
    optimized: bool = True                # Phase 7 optimizations applied
    bw_mode: str = "realistic"            # "idle" or "realistic"
    amortize_months: int = 12

    def compute(self) -> dict:
        """Return dict of derived capacity numbers."""
        kb_per_conn = RAM_KB_PER_CONN_OPTIMIZED if self.optimized else RAM_KB_PER_CONN_BASELINE
        if self.nginx:
            kb_per_conn += RAM_KB_PER_CONN_NGINX_OVERHEAD

        if self.optimized:
            bw_per_conn = (BW_BYTES_PER_CONN_OPTIMIZED_IDLE if self.bw_mode == "idle"
                           else BW_BYTES_PER_CONN_OPTIMIZED_REALISTIC)
        else:
            bw_per_conn = (BW_BYTES_PER_CONN_BASELINE_IDLE if self.bw_mode == "idle"
                           else BW_BYTES_PER_CONN_BASELINE_REALISTIC)

        # RAM cap
        usable_ram_gb = max(0.0, self.ram_gb - OS_RESERVE_GB)
        ram_cap = int(usable_ram_gb * 1024 * 1024 * 1024 / (kb_per_conn * 1024))

        # Bandwidth cap (Gbps → bytes/sec)
        bw_bytes_sec = self.bw_gbps * 1_000_000_000 / 8
        bw_cap = int(bw_bytes_sec / bw_per_conn) if bw_per_conn > 0 else 0

        # CPU cap — conservative rate covers any CPU 2015+
        sustainable_auths_sec = self.threads * CPU_AUTHS_PER_THREAD_CONSERVATIVE * CPU_HEADROOM
        cpu_cap = int(sustainable_auths_sec / RECONNECT_RATE_PER_SEC) if RECONNECT_RATE_PER_SEC > 0 else 0

        # Pick limiting resource
        limits = {"RAM": ram_cap, "BW": bw_cap, "CPU": cpu_cap}
        bottleneck = min(limits, key=limits.get)
        real_cap = limits[bottleneck]

        # Monthly traffic at ceiling
        monthly_tb = real_cap * bw_per_conn * 86400 * 30 / 1_000_000_000_000

        # Overage cost if capped plan
        if self.traffic_tb_cap > 0 and monthly_tb > self.traffic_tb_cap:
            overage_tb = monthly_tb - self.traffic_tb_cap
            overage_usd = overage_tb * self.overage_per_tb_usd
        else:
            overage_tb = 0.0
            overage_usd = 0.0

        effective_monthly = self.price_usd_mo + overage_usd + (self.setup_usd / max(self.amortize_months, 1))
        per_user_usd = (effective_monthly / real_cap) if real_cap > 0 else float("inf")
        registered_users = int(real_cap / PEAK_CONCURRENCY)

        return {
            "ram_cap": ram_cap,
            "bw_cap": bw_cap,
            "cpu_cap": cpu_cap,
            "real_cap": real_cap,
            "bottleneck": bottleneck,
            "monthly_tb": monthly_tb,
            "overage_tb": overage_tb,
            "overage_usd": overage_usd,
            "effective_monthly": effective_monthly,
            "per_user_usd": per_user_usd,
            "registered_users": registered_users,
        }


# ---------------------------------------------------------------------------
# Formatting helpers
# ---------------------------------------------------------------------------

def fmt_n(n: float) -> str:
    if n >= 1_000_000: return f"{n/1_000_000:.2f}M"
    if n >= 1_000:     return f"{n/1_000:.1f}k"
    return f"{int(n)}"

def fmt_usd(x: float) -> str:
    if x < 0.001:  return f"${x:.7f}"
    if x < 1:      return f"${x:.4f}"
    return f"${x:,.2f}"


# ---------------------------------------------------------------------------
# Editor dialog embedded as a form panel (simpler than a modal dialog)
# ---------------------------------------------------------------------------

class ServerEditor(QGroupBox):
    """Form panel to edit one server's fields."""

    def __init__(self, on_apply, on_clear):
        super().__init__("Add / Edit Server")
        self._on_apply = on_apply
        self._on_clear = on_clear

        form = QFormLayout()

        self.name = QLineEdit()
        self.ram_gb = QDoubleSpinBox(); self.ram_gb.setRange(1, 10_000); self.ram_gb.setValue(64)
        self.bw_gbps = QDoubleSpinBox(); self.bw_gbps.setRange(0.001, 400); self.bw_gbps.setDecimals(3); self.bw_gbps.setValue(1.0)
        self.cores = QSpinBox(); self.cores.setRange(1, 512); self.cores.setValue(8)
        self.threads = QSpinBox(); self.threads.setRange(1, 1024); self.threads.setValue(16)
        self.price = QDoubleSpinBox(); self.price.setRange(0, 100_000); self.price.setValue(50)
        self.setup = QDoubleSpinBox(); self.setup.setRange(0, 100_000); self.setup.setValue(0)
        self.traffic_tb = QDoubleSpinBox(); self.traffic_tb.setRange(0, 10_000); self.traffic_tb.setValue(0)
        self.overage = QDoubleSpinBox(); self.overage.setRange(0, 1000); self.overage.setValue(1.0)
        self.amortize_months = QSpinBox(); self.amortize_months.setRange(1, 120); self.amortize_months.setValue(12)
        self.nginx = QCheckBox("Nginx in front (+53 KB/conn)")
        self.optimized = QCheckBox("Phase 7 optimizations applied")
        self.optimized.setChecked(True)
        self.bw_mode = QComboBox(); self.bw_mode.addItems(["realistic", "idle"])

        form.addRow("Name:", self.name)
        form.addRow("RAM (GB):", self.ram_gb)
        form.addRow("Bandwidth (Gbps):", self.bw_gbps)
        form.addRow("Cores:", self.cores)
        form.addRow("Threads:", self.threads)
        form.addRow("Price ($/mo):", self.price)
        form.addRow("Setup fee ($):", self.setup)
        form.addRow("Amortize setup (months):", self.amortize_months)
        form.addRow("Traffic cap (TB/mo, 0=unmetered):", self.traffic_tb)
        form.addRow("Overage ($/TB):", self.overage)
        form.addRow("", self.nginx)
        form.addRow("", self.optimized)
        form.addRow("BW mode:", self.bw_mode)

        btn_row = QHBoxLayout()
        btn_add = QPushButton("Add as new server")
        btn_update = QPushButton("Update selected")
        btn_clear = QPushButton("Clear form")
        btn_add.clicked.connect(lambda: self._on_apply(False))
        btn_update.clicked.connect(lambda: self._on_apply(True))
        btn_clear.clicked.connect(on_clear)
        btn_row.addWidget(btn_add); btn_row.addWidget(btn_update); btn_row.addWidget(btn_clear)

        layout = QVBoxLayout()
        layout.addLayout(form)
        layout.addLayout(btn_row)
        self.setLayout(layout)

    def get_server(self) -> Server:
        return Server(
            name=self.name.text().strip() or "Unnamed",
            ram_gb=self.ram_gb.value(),
            bw_gbps=self.bw_gbps.value(),
            cores=self.cores.value(),
            threads=self.threads.value(),
            price_usd_mo=self.price.value(),
            setup_usd=self.setup.value(),
            traffic_tb_cap=self.traffic_tb.value(),
            overage_per_tb_usd=self.overage.value(),
            nginx=self.nginx.isChecked(),
            optimized=self.optimized.isChecked(),
            bw_mode=self.bw_mode.currentText(),
            amortize_months=self.amortize_months.value(),
        )

    def set_server(self, s: Server):
        self.name.setText(s.name)
        self.ram_gb.setValue(s.ram_gb)
        self.bw_gbps.setValue(s.bw_gbps)
        self.cores.setValue(s.cores)
        self.threads.setValue(s.threads)
        self.price.setValue(s.price_usd_mo)
        self.setup.setValue(s.setup_usd)
        self.traffic_tb.setValue(s.traffic_tb_cap)
        self.overage.setValue(s.overage_per_tb_usd)
        self.nginx.setChecked(s.nginx)
        self.optimized.setChecked(s.optimized)
        idx = self.bw_mode.findText(s.bw_mode)
        if idx >= 0: self.bw_mode.setCurrentIndex(idx)
        self.amortize_months.setValue(s.amortize_months)

    def clear(self):
        self.set_server(Server())


# ---------------------------------------------------------------------------
# Main window
# ---------------------------------------------------------------------------

COLUMNS = [
    "Name", "RAM (GB)", "BW (Gbps)", "C/T", "$/mo", "Setup",
    "Max users", "Bottleneck", "Registered", "$/user/mo", "Traffic (TB/mo)", "Effective $/mo",
]

class MainWindow(QMainWindow):
    def __init__(self):
        super().__init__()
        self.setWindowTitle("Hollow Capacity Calculator")
        self.resize(1500, 800)
        self.servers: list[Server] = []

        central = QWidget()
        layout = QHBoxLayout(central)

        # Left: editor panel
        self.editor = ServerEditor(self._on_editor_apply, self._on_editor_clear)
        self.editor.setFixedWidth(420)
        layout.addWidget(self.editor)

        # Right: table + buttons
        right = QVBoxLayout()

        top_buttons = QHBoxLayout()
        self.btn_delete = QPushButton("Delete selected")
        self.btn_save = QPushButton("Save list…")
        self.btn_load = QPushButton("Load list…")
        self.btn_preset = QPushButton("Load presets")
        self.btn_delete.clicked.connect(self._delete_selected)
        self.btn_save.clicked.connect(self._save)
        self.btn_load.clicked.connect(self._load)
        self.btn_preset.clicked.connect(self._load_presets)
        top_buttons.addWidget(self.btn_preset)
        top_buttons.addWidget(self.btn_save)
        top_buttons.addWidget(self.btn_load)
        top_buttons.addWidget(self.btn_delete)
        top_buttons.addStretch()
        right.addLayout(top_buttons)

        self.table = QTableWidget()
        self.table.setColumnCount(len(COLUMNS))
        self.table.setHorizontalHeaderLabels(COLUMNS)
        self.table.setSortingEnabled(True)
        self.table.setSelectionBehavior(QTableWidget.SelectRows)
        self.table.setEditTriggers(QTableWidget.NoEditTriggers)
        self.table.itemSelectionChanged.connect(self._on_row_selected)
        header = self.table.horizontalHeader()
        header.setSectionResizeMode(QHeaderView.Interactive)
        header.setStretchLastSection(True)
        right.addWidget(self.table)

        self.status = QLabel("Add servers using the form on the left, or click 'Load presets' to start with known options.")
        self.status.setStyleSheet("color: gray;")
        right.addWidget(self.status)

        layout.addLayout(right)
        self.setCentralWidget(central)

    # ----- table sync -----
    def _refresh_table(self):
        self.table.setSortingEnabled(False)
        self.table.setRowCount(len(self.servers))
        for row, s in enumerate(self.servers):
            r = s.compute()
            traffic_text = f"{r['monthly_tb']:.1f}"
            if r['overage_usd'] > 0:
                traffic_text += f" (+${r['overage_usd']:.0f})"
            values = [
                s.name,
                f"{s.ram_gb:g}",
                f"{s.bw_gbps:g}",
                f"{s.cores}/{s.threads}",
                fmt_usd(s.price_usd_mo),
                fmt_usd(s.setup_usd) if s.setup_usd > 0 else "-",
                fmt_n(r['real_cap']),
                r['bottleneck'],
                fmt_n(r['registered_users']),
                fmt_usd(r['per_user_usd']),
                traffic_text,
                fmt_usd(r['effective_monthly']),
            ]
            for col, text in enumerate(values):
                item = QTableWidgetItem(text)
                item.setData(Qt.UserRole, self._sort_key(col, s, r))
                if col == 7:  # bottleneck column
                    color = {"RAM": QColor(255, 230, 200), "BW": QColor(255, 200, 200), "CPU": QColor(200, 230, 255)}.get(r['bottleneck'])
                    if color: item.setBackground(color)
                self.table.setItem(row, col, item)
        self.table.resizeColumnsToContents()
        self.table.setSortingEnabled(True)
        self.status.setText(f"{len(self.servers)} servers in comparison. Click a row to edit. Click column headers to sort.")

    def _sort_key(self, col: int, s: Server, r: dict):
        # Numeric columns sort numerically.
        numeric = {
            1: s.ram_gb, 2: s.bw_gbps, 3: s.threads, 4: s.price_usd_mo, 5: s.setup_usd,
            6: r['real_cap'], 8: r['registered_users'], 9: r['per_user_usd'],
            10: r['monthly_tb'], 11: r['effective_monthly'],
        }
        return numeric.get(col, None)

    # ----- editor callbacks -----
    def _on_editor_apply(self, update: bool):
        s = self.editor.get_server()
        if update:
            row = self.table.currentRow()
            if row < 0 or row >= len(self.servers):
                QMessageBox.information(self, "No selection", "Select a row in the table first.")
                return
            self.servers[row] = s
        else:
            self.servers.append(s)
        self._refresh_table()

    def _on_editor_clear(self):
        self.editor.clear()
        self.table.clearSelection()

    def _on_row_selected(self):
        row = self.table.currentRow()
        if 0 <= row < len(self.servers):
            self.editor.set_server(self.servers[row])

    def _delete_selected(self):
        row = self.table.currentRow()
        if row < 0: return
        del self.servers[row]
        self._refresh_table()

    # ----- persistence -----
    def _save(self):
        path, _ = QFileDialog.getSaveFileName(self, "Save comparison", "", "JSON (*.json)")
        if not path: return
        data = [s.__dict__ for s in self.servers]
        Path(path).write_text(json.dumps(data, indent=2))
        self.status.setText(f"Saved {len(self.servers)} servers to {path}")

    def _load(self):
        path, _ = QFileDialog.getOpenFileName(self, "Load comparison", "", "JSON (*.json)")
        if not path: return
        data = json.loads(Path(path).read_text())
        valid_fields = {f.name for f in Server.__dataclass_fields__.values()}
        self.servers = [Server(**{k: v for k, v in d.items() if k in valid_fields}) for d in data]
        self._refresh_table()
        self.status.setText(f"Loaded {len(self.servers)} servers from {path}")

    def _load_presets(self):
        self.servers = [
            Server(name="OVH 8 GB VPS (current)", ram_gb=8, bw_gbps=0.4, cores=4, threads=4,
                   price_usd_mo=8.35, nginx=True),
            Server(name="OVH 12 GB VPS", ram_gb=12, bw_gbps=1.0, cores=6, threads=6,
                   price_usd_mo=12.75, nginx=True),
            Server(name="Hetzner auction 256 GB Xeon E5", ram_gb=256, bw_gbps=1.0, cores=6, threads=12,
                   price_usd_mo=74.90),
            Server(name="Hetzner auction 64 GB Ryzen 3600", ram_gb=64, bw_gbps=1.0, cores=6, threads=12,
                   price_usd_mo=43.90),
            Server(name="Hetzner EX44 (i5-13500)", ram_gb=128, bw_gbps=10, cores=14, threads=20,
                   price_usd_mo=123, setup_usd=100, traffic_tb_cap=20, overage_per_tb_usd=1.0),
            Server(name="Hetzner EX130-R (Xeon Gold 5412U)", ram_gb=256, bw_gbps=10, cores=24, threads=48,
                   price_usd_mo=232, setup_usd=562, traffic_tb_cap=20, overage_per_tb_usd=1.0),
            Server(name="GThost DET-SM6029TP-HTR-26-2", ram_gb=192, bw_gbps=3, cores=12, threads=24,
                   price_usd_mo=248),
            Server(name="GThost MTL-SM2029TP-HC1R-12-1", ram_gb=384, bw_gbps=3, cores=24, threads=48,
                   price_usd_mo=288),
            Server(name="DataPacket dedicated 256 GB", ram_gb=256, bw_gbps=50, cores=24, threads=48,
                   price_usd_mo=790),
        ]
        self._refresh_table()


def main():
    app = QApplication(sys.argv)
    w = MainWindow()
    w.show()
    sys.exit(app.exec())


if __name__ == "__main__":
    main()
