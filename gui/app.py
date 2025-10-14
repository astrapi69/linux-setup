#!/usr/bin/env python3
import asyncio
import json
import sys
import qasync
import os
import subprocess
import signal
import sys
from PySide6 import QtWidgets, QtCore
from dbus_next.aio import MessageBus
from dbus_next import BusType
from backend_client import BackendClient

class MainWindow(QtWidgets.QWidget):
    def __init__(self, client: BackendClient):
        super().__init__()
        self.client = client
        self.setWindowTitle("Linux Setup – Security Dashboard")
        self.resize(800, 600)

        # Main layout
        self.main_layout = QtWidgets.QVBoxLayout(self)

        # Status bar
        self.status_label = QtWidgets.QLabel("Loading latest report...")
        self.main_layout.addWidget(self.status_label)

        # Scroll area for findings
        self.scroll = QtWidgets.QScrollArea()
        self.scroll.setWidgetResizable(True)
        self.scroll_content = QtWidgets.QWidget()
        self.findings_layout = QtWidgets.QVBoxLayout(self.scroll_content)
        self.scroll.setWidget(self.scroll_content)
        self.main_layout.addWidget(self.scroll)

        # Buttons
        btn_row = QtWidgets.QHBoxLayout()
        self.btn_audit = QtWidgets.QPushButton("Run Quick Audit")
        self.btn_harden = QtWidgets.QPushButton("Apply All Safe Fixes")
        self.btn_open_report = QtWidgets.QPushButton("Open Full Report")
        btn_row.addWidget(self.btn_audit)
        btn_row.addWidget(self.btn_harden)
        btn_row.addWidget(self.btn_open_report)
        self.main_layout.addLayout(btn_row)

        # Connect buttons
        self.btn_audit.clicked.connect(lambda: asyncio.create_task(self.run_audit()))
        self.btn_harden.clicked.connect(lambda: asyncio.create_task(self.apply_all_safe()))
        self.btn_open_report.clicked.connect(self.open_report)

        # Load data
        asyncio.create_task(self.load_latest())

    def clear_findings(self):
        while self.findings_layout.count():
            child = self.findings_layout.takeAt(0)
            if child.widget():
                child.widget().deleteLater()

    async def load_latest(self):
        try:
            data = await self.client.get_latest()
            state = data.get("state", {})
            findings = state.get("findings", [])
            self.display_findings(findings)
            self.status_label.setText(f"✅ Last run: {state.get('ts', 'unknown')} | {len(findings)} findings")
        except Exception as e:
            self.status_label.setText(f"❌ Failed to load report: {e}")

    def display_findings(self, findings):
        self.clear_findings()
        if not findings:
            self.findings_layout.addWidget(QtWidgets.QLabel("No security findings. System looks good! 🛡️"))
            return

        for f in findings:
            card = self.create_finding_card(f)
            self.findings_layout.addWidget(card)

        self.findings_layout.addStretch()

    def create_finding_card(self, finding):
        frame = QtWidgets.QFrame()
        frame.setFrameShape(QtWidgets.QFrame.Shape.StyledPanel)
        layout = QtWidgets.QVBoxLayout(frame)

        # Title + severity
        title = QtWidgets.QLabel(f"<b>{finding['title']}</b>")
        severity = finding.get("severity", "info").lower()
        color = {"high": "red", "medium": "orange", "low": "green"}.get(severity, "gray")
        title.setStyleSheet(f"color: {color}; font-size: 14px;")

        # Description
        desc = QtWidgets.QLabel(finding.get("description", ""))
        desc.setWordWrap(True)

        # Fix button
        btn_fix = QtWidgets.QPushButton("Apply Fix")
        btn_fix.clicked.connect(lambda _, fid=finding["id"]: asyncio.create_task(self.apply_fix(fid)))

        layout.addWidget(title)
        layout.addWidget(desc)
        layout.addWidget(btn_fix)

        # Links (optional)
        links = finding.get("links", [])
        if links:
            link_label = QtWidgets.QLabel(f"<a href='{links[0]}'>Learn more</a>")
            link_label.setOpenExternalLinks(True)
            layout.addWidget(link_label)

        return frame

    async def apply_fix(self, fix_id: str):
        try:
            result = await self.client.fix(fix_id)
            self.status_label.setText(f"✅ Applied fix: {fix_id}")
            asyncio.create_task(self.load_latest())  # refresh
        except Exception as e:
            self.status_label.setText(f"❌ Fix failed: {e}")

    async def apply_all_safe(self):
        self.status_label.setText("Applying all safe fixes...")
        # For now, just re-run harden
        await self.client.harden(profile="desktop")
        asyncio.create_task(self.load_latest())

    async def run_audit(self):
        self.status_label.setText("Running quick audit...")
        await self.client.audit(profile="desktop", quick=True)
        asyncio.create_task(self.load_latest())

    def open_report(self):
        report_path = "/home/astrapi69/linux-setup-report/latest.md"
        if os.path.exists(report_path):
            subprocess.run(["xdg-open", report_path])
        else:
            self.status_label.setText("Report not found.")


def main():
    # Handle Ctrl+C gracefully
    signal.signal(signal.SIGINT, signal.SIG_DFL)

    app = QtWidgets.QApplication(sys.argv)
    loop = qasync.QEventLoop(app)
    asyncio.set_event_loop(loop)

    client = BackendClient()

    async def run():
        await client.connect()
        window = MainWindow(client)
        window.show()
        while window.isVisible():
            await asyncio.sleep(0.1)

    try:
        with loop:
            loop.run_until_complete(run())
    except KeyboardInterrupt:
        print("\nExiting gracefully...")
        sys.exit(0)


if __name__ == "__main__":
    main()