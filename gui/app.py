# gui/app.py
import sys
import signal
import asyncio
from PySide6 import QtWidgets
import qasync
from .backend_client import BackendClient
from .main_window import MainWindow


def main():
    """
    Entry point for the Security Dashboard GUI.
    Sets up a qasync event loop so Qt + asyncio play nicely.
    """

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