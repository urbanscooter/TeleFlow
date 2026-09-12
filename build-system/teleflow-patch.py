#!/usr/bin/env python3
"""
TeleFlow auto-patcher: заменяет блок удаления сообщений в TelegramCore
на вызов TeleFlowAntiDeleteService.handleIncomingMessageDeletions(account:messageIds:).

Что делаем:
  было:
      let _ = (account.postbox.transaction { transaction -> Void in
          for id in messageIds {
              transaction.removeMessage(id)
          }
      }).start()

  стало:
      // TeleFlow: patched
      TeleFlowAntiDeleteService.shared.handleIncomingMessageDeletions(account: account, messageIds: messageIds)

Теперь сервис сам решает: если анти-удаление включено — помечает сообщения,
не удаляя их из постбокса (бабл остаётся видимым); если выключено — удаляет штатно.

Идемпотентный: повторный запуск ничего не делает (проверяет MARKER).
Патчится ТОЛЬКО cloud-вариант (там, где цикл идёт по `messageIds`).
"""
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# Файлы-кандидаты (по приоритету)
CANDIDATES = [
    "submodules/TelegramCore/Sources/State/CloudChatRemoveMessagesOperation.swift",
    "submodules/TelegramCore/Sources/State/ManagedCloudChatRemoveMessagesOperations.swift",
]

MARKER = "// TeleFlow: patched"

REPLACEMENT_TEMPLATE = (
    "{indent}// TeleFlow: patched\n"
    "{indent}TeleFlowAntiDeleteService.shared.handleIncomingMessageDeletions("
    "account: account, messageIds: messageIds)\n"
)

# Матчим весь блок:
#   let _ = (account.postbox.transaction { ... }).start()
# `.*?` не-жадный, но так как `.start()` встречается только на закрытии
# транзакции, этого достаточно. Внутренние `}` цикла `for` не помешают,
# потому что после них идёт `}`, а не `}).start()`.
BLOCK_PATTERN = re.compile(
    r"(?P<indent>[ \t]*)let\s+_\s*=\s*\(\s*account\.postbox\.transaction\s*\{"
    r".*?"
    r"\}\s*\)\s*\.start\s*\(\s*\)",
    re.DOTALL,
)

# Признаки именно cloud-варианта:
LOOP_OVER_MESSAGE_IDS = re.compile(r"\bfor\s+\w+\s+in\s+messageIds\b")
HAS_REMOVE_CALL = re.compile(r"\btransaction\.removeMessage\s*\(")


def find_target_file():
    """Возвращает (path, content) первого файла, где найден cloud-блок."""
    for rel in CANDIDATES:
        path = os.path.join(ROOT, rel)
        if not os.path.isfile(path):
            continue
        with open(path, "r", encoding="utf-8") as f:
            content = f.read()
        if LOOP_OVER_MESSAGE_IDS.search(content) and HAS_REMOVE_CALL.search(content):
            return path, content

    # Резервный поиск по всему TelegramCore
    sources_dir = os.path.join(ROOT, "submodules/TelegramCore/Sources")
    if not os.path.isdir(sources_dir):
        return None, None
    for dirpath, _, filenames in os.walk(sources_dir):
        for name in filenames:
            if not name.endswith(".swift"):
                continue
            path = os.path.join(dirpath, name)
            try:
                with open(path, "r", encoding="utf-8") as f:
                    content = f.read()
            except Exception:
                continue
            if LOOP_OVER_MESSAGE_IDS.search(content) and HAS_REMOVE_CALL.search(content):
                return path, content
    return None, None


def patch(content):
    """Возвращает (new_content, status)."""
    if MARKER in content:
        return content, "already-patched"

    replaced = {"count": 0}

    def repl(match):
        block = match.group(0)
        # Трогаем только cloud-вариант: цикл по messageIds + removeMessage.
        if not (LOOP_OVER_MESSAGE_IDS.search(block) and HAS_REMOVE_CALL.search(block)):
            return block  # чужой removeMessage (secret chat и т.п.) — не трогаем
        replaced["count"] += 1
        return REPLACEMENT_TEMPLATE.format(indent=match.group("indent"))

    new_content = BLOCK_PATTERN.sub(repl, content)

    if replaced["count"] == 0:
        return content, "no-injection-point"
    return new_content, "patched"


def main():
    path, content = find_target_file()
    if path is None:
        print("TeleFlow patch: target file not found — skipping (submodules may not be synced)")
        sys.exit(0)

    new_content, status = patch(content)
    if status == "already-patched":
        print(f"TeleFlow patch: already patched ({os.path.relpath(path, ROOT)})")
        return
    if status == "no-injection-point":
        print(f"TeleFlow patch: no cloud-removal block matched in {os.path.relpath(path, ROOT)} — skipping")
        sys.exit(0)

    # Бэкап (один раз)
    backup = path + ".teleflow-bak"
    if not os.path.exists(backup):
        with open(backup, "w", encoding="utf-8") as f:
            f.write(content)

    with open(path, "w", encoding="utf-8") as f:
        f.write(new_content)

    print(f"TeleFlow patch: patched {os.path.relpath(path, ROOT)}")


if __name__ == "__main__":
    main()
