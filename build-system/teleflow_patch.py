#!/usr/bin/env python3
"""
TeleFlow auto-patcher: встраивает хук анти-удаления в пайплайн TelegramCore.
Идемпотентный — можно запускать сколько угодно раз, повторно не патчит.
"""
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# Файлы, где ищем точку удаления (по приоритету)
CANDIDATES = [
    "submodules/TelegramCore/Sources/State/CloudChatRemoveMessagesOperation.swift",
    "submodules/TelegramCore/Sources/State/ManagedCloudChatRemoveMessagesOperations.swift",
]

INJECT_MARKER = "// TeleFlow: hook injected"
INJECT_LINE = "        TeleFlowAntiDeleteService.shared.handleIncomingMessageDeletions(account: account, messageIds: messageIds)\n"
CALL_PATTERN = re.compile(r"transaction\.removeMessage\(")
LOOP_PATTERN = re.compile(r"for\s+(\w+)\s+in\s+(\w+)\s*\{")


def find_target_file():
    for rel in CANDIDATES:
        path = os.path.join(ROOT, rel)
        if os.path.isfile(path):
            with open(path, "r", encoding="utf-8") as f:
                content = f.read()
            if CALL_PATTERN.search(content):
                return path, content
    # Резервный поиск по всему TelegramCore
    state_dir = os.path.join(ROOT, "submodules/TelegramCore/Sources")
    for dirpath, _, filenames in os.walk(state_dir):
        for name in filenames:
            if not name.endswith(".swift"):
                continue
            path = os.path.join(dirpath, name)
            try:
                with open(path, "r", encoding="utf-8") as f:
                    content = f.read()
            except Exception:
                continue
            if CALL_PATTERN.search(content) and "messageIds" in content:
                return path, content
    return None, None


def inject(content):
    if INJECT_MARKER in content:
        return content, "already-patched"

    lines = content.split("\n")
    out = []
    injected = False
    last_loop_var = None
    last_loop_collection = None

    for line in lines:
        # Запоминаем переменные цикла — вдруг понадобится
        m = LOOP_PATTERN.search(line)
        if m:
            last_loop_var = m.group(1)
            last_loop_collection = m.group(2)

        # Точка вставки — первая строка с transaction.removeMessage
        if not injected and CALL_PATTERN.search(line):
            indent = len(line) - len(line.lstrip())
            indent_str = " " * indent
            # Используем массив messageIds, если он доступен; иначе [<loop_var>]
            if "messageIds" in content or (last_loop_collection and last_loop_collection != "messageIds"):
                payload = f"{indent_str}{INJECT_MARKER}\n{indent_str}TeleFlowAntiDeleteService.shared.handleIncomingMessageDeletions(account: account, messageIds: messageIds)\n"
            else:
                lv = last_loop_var or "id"
                payload = f"{indent_str}{INJECT_MARKER}\n{indent_str}TeleFlowAntiDeleteService.shared.handleIncomingMessageDeletions(account: account, messageIds: [{lv}])\n"
            out.append(payload.rstrip("\n"))
            injected = True
        out.append(line)

    if not injected:
        return content, "no-injection-point"

    return "\n".join(out), "patched"


def main():
    path, content = find_target_file()
    if path is None:
        print("TeleFlow patch: target file not found")
        sys.exit(1)

    new_content, status = inject(content)
    if status == "already-patched":
        print(f"TeleFlow patch: already patched ({os.path.relpath(path, ROOT)})")
        return
    if status == "no-injection-point":
        print(f"TeleFlow patch: no injection point in {os.path.relpath(path, ROOT)}")
        sys.exit(1)

    # Бэкап
    backup = path + ".teleflow-bak"
    if not os.path.exists(backup):
        with open(backup, "w", encoding="utf-8") as f:
            f.write(content)

    with open(path, "w", encoding="utf-8") as f:
        f.write(new_content)

    print(f"TeleFlow patch: patched {os.path.relpath(path, ROOT)}")


if __name__ == "__main__":
    main()
