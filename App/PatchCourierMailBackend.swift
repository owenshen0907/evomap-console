import Foundation
import Security
import Darwin

enum PatchCourierMailSecurity: String, Codable, CaseIterable, Identifiable {
    case sslTLS
    case startTLS
    case plain

    var id: String { rawValue }

    var title: String {
        switch self {
        case .sslTLS:
            return "SSL/TLS"
        case .startTLS:
            return "STARTTLS"
        case .plain:
            return AppLocalization.string("mail.security.plain", fallback: "Plain")
        }
    }
}

struct PatchCourierMailEndpoint: Codable, Hashable {
    var host: String
    var port: Int
    var security: PatchCourierMailSecurity
}

struct PatchCourierMailAccount: Codable, Hashable {
    var id: String
    var label: String
    var emailAddress: String
    var role: String
    var workspaceRoot: String
    var imap: PatchCourierMailEndpoint
    var smtp: PatchCourierMailEndpoint
    var pollingIntervalSeconds: Int
    var createdAt: Date
    var updatedAt: Date
}

struct PatchCourierOutboundMailMessage: Codable, Hashable {
    var to: [String]
    var subject: String
    var plainBody: String
    var htmlBody: String?
    var inReplyTo: String?
    var references: [String]
}

struct PatchCourierInboundMailMessage: Codable, Hashable, Identifiable {
    var uid: UInt64
    var messageID: String
    var fromAddress: String
    var fromDisplayName: String?
    var subject: String
    var plainBody: String
    var receivedAt: Date
    var inReplyTo: String?
    var references: [String]

    var id: String { "\(uid)::\(messageID)" }
}

struct PatchCourierMailSendResult: Codable, Hashable {
    var messageID: String
}

struct PatchCourierMailHistoryResult: Codable, Hashable {
    var visibleCount: Int
    var messages: [PatchCourierInboundMailMessage]
}

struct PatchCourierMailProbeResult: Codable, Hashable {
    var imap: LegStatus
    var smtp: LegStatus

    struct LegStatus: Codable, Hashable {
        var ok: Bool
        var detail: String?
    }
}

struct PatchCourierExecutionResult: Hashable {
    var requestID: String?
    var taskID: String?
    var status: String?
    var confidence: String?
    var needsUserInput: Bool?
    var riskFlags: String?
    var finalAnswerMarkdown: String?
    var rawBody: String
    var messageID: String
    var receivedAt: Date
    var threadToken: String?

    var isUsableFinalAnswer: Bool {
        finalAnswerMarkdown?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
    }
}

protocol PatchCourierMailPasswordStoring {
    func loadPassword(account: String) throws -> String?
    func savePassword(_ password: String, account: String) throws
    func deletePassword(account: String) throws
}

enum PatchCourierMailPasswordStoreError: LocalizedError {
    case invalidPasswordEncoding
    case unhandledStatus(OSStatus)

    var errorDescription: String? {
        switch self {
        case .invalidPasswordEncoding:
            return AppLocalization.string("settings.patch_courier.backend.password_encoding_error", fallback: "The mail app password could not be encoded for secure storage.")
        case .unhandledStatus(let status):
            if let message = SecCopyErrorMessageString(status, nil) as String? {
                return message
            }
            return AppLocalization.string("settings.patch_courier.backend.keychain_error", fallback: "Keychain operation failed with status %d.", Int(status))
        }
    }
}

struct KeychainPatchCourierMailPasswordStore: PatchCourierMailPasswordStoring {
    private let service = "dev.evomapconsole.patch-courier-mail"

    func loadPassword(account: String) throws -> String? {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
            kSecMatchLimit: kSecMatchLimitOne,
            kSecReturnData: true,
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        switch status {
        case errSecSuccess:
            guard let data = result as? Data else { return nil }
            return String(data: data, encoding: .utf8)
        case errSecItemNotFound:
            return nil
        default:
            throw PatchCourierMailPasswordStoreError.unhandledStatus(status)
        }
    }

    func savePassword(_ password: String, account: String) throws {
        guard let data = password.data(using: .utf8) else {
            throw PatchCourierMailPasswordStoreError.invalidPasswordEncoding
        }

        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
        ]

        let attributes: [CFString: Any] = [
            kSecValueData: data,
            kSecAttrAccessible: kSecAttrAccessibleAfterFirstUnlock,
        ]

        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        switch status {
        case errSecSuccess:
            return
        case errSecItemNotFound:
            var createQuery = query
            createQuery[kSecValueData] = data
            createQuery[kSecAttrAccessible] = kSecAttrAccessibleAfterFirstUnlock
            let addStatus = SecItemAdd(createQuery as CFDictionary, nil)
            guard addStatus == errSecSuccess else {
                throw PatchCourierMailPasswordStoreError.unhandledStatus(addStatus)
            }
        default:
            throw PatchCourierMailPasswordStoreError.unhandledStatus(status)
        }
    }

    func deletePassword(account: String) throws {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
        ]

        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw PatchCourierMailPasswordStoreError.unhandledStatus(status)
        }
    }
}

enum PatchCourierMailTransportError: LocalizedError {
    case pythonNotFound
    case launchFailed(String)
    case commandFailed(command: String, details: String?)
    case invalidResponse(command: String, details: String?)

    var errorDescription: String? {
        switch self {
        case .pythonNotFound:
            return AppLocalization.string("patch_courier.backend.error.python_missing", fallback: "Python 3 is required for IMAP/SMTP transport, but no python3 executable was found.")
        case .launchFailed(let details):
            return AppLocalization.string("patch_courier.backend.error.launch_failed", fallback: "Mail transport helper could not start: %@", details)
        case .commandFailed(let command, let details):
            return AppLocalization.string("patch_courier.backend.error.command_failed", fallback: "Mail transport command %@ failed: %@", command, details ?? AppLocalization.unknown)
        case .invalidResponse(let command, let details):
            return AppLocalization.string("patch_courier.backend.error.invalid_response", fallback: "Mail transport command %@ returned an unreadable response: %@", command, details ?? AppLocalization.unknown)
        }
    }
}

struct PatchCourierMailTransportClient {
    let scriptURL: URL
    let pythonCandidates: [String]

    init(
        scriptURL: URL = ConsoleAppSettings.patchCourierMailTransportScriptURL,
        pythonCandidates: [String] = [
            "/usr/bin/python3",
            "/opt/homebrew/bin/python3",
            "/usr/local/bin/python3"
        ]
    ) {
        self.scriptURL = scriptURL
        self.pythonCandidates = pythonCandidates
    }

    func sendMessage(
        account: PatchCourierMailAccount,
        password: String,
        message: PatchCourierOutboundMailMessage
    ) throws -> PatchCourierMailSendResult {
        try run(command: "send", payload: MailSendPayload(account: account, password: password, message: message), decode: PatchCourierMailSendResult.self)
    }

    func fetchRecentHistory(
        account: PatchCourierMailAccount,
        password: String,
        limit: Int = 50
    ) throws -> PatchCourierMailHistoryResult {
        try run(command: "history", payload: MailHistoryPayload(account: account, password: password, limit: limit), decode: PatchCourierMailHistoryResult.self)
    }

    func probe(account: PatchCourierMailAccount, password: String) throws -> PatchCourierMailProbeResult {
        try run(command: "probe", payload: MailProbePayload(account: account, password: password), decode: PatchCourierMailProbeResult.self)
    }

    private func run<Payload: Encodable, Output: Decodable>(
        command: String,
        payload: Payload,
        decode: Output.Type
    ) throws -> Output {
        try installScriptIfNeeded()
        let pythonURL = try resolvePythonURL()
        let process = Process()
        process.executableURL = pythonURL
        process.arguments = [scriptURL.path, command]

        let stdinPipe = Pipe()
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardInput = stdinPipe
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        let encodedPayload = try encoder.encode(payload)

        do {
            try process.run()
        } catch {
            throw PatchCourierMailTransportError.launchFailed(error.localizedDescription)
        }

        stdinPipe.fileHandleForWriting.write(encodedPayload)
        try? stdinPipe.fileHandleForWriting.close()

        let timeoutSeconds: TimeInterval = 45
        let deadline = Date().addingTimeInterval(timeoutSeconds)
        while process.isRunning && Date() < deadline {
            Thread.sleep(forTimeInterval: 0.05)
        }

        if process.isRunning {
            process.terminate()
            Thread.sleep(forTimeInterval: 0.5)
            if process.isRunning {
                kill(process.processIdentifier, SIGKILL)
            }
            process.waitUntilExit()
            throw PatchCourierMailTransportError.commandFailed(
                command: command,
                details: "Timed out after \(Int(timeoutSeconds)) seconds."
            )
        }

        let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
        let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
        let stderr = String(decoding: stderrData, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)

        guard process.terminationStatus == 0 else {
            throw PatchCourierMailTransportError.commandFailed(command: command, details: stderr.nonEmpty)
        }

        do {
            return try decoder.decode(Output.self, from: stdoutData)
        } catch {
            let raw = String(decoding: stdoutData, as: UTF8.self)
            throw PatchCourierMailTransportError.invalidResponse(command: command, details: raw.nonEmpty ?? stderr.nonEmpty)
        }
    }

    private func installScriptIfNeeded() throws {
        try FileManager.default.createDirectory(
            at: scriptURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let contents = Self.pythonScript
        let existing = try? String(contentsOf: scriptURL, encoding: .utf8)
        guard existing != contents else { return }
        try contents.write(to: scriptURL, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: scriptURL.path)
    }

    private func resolvePythonURL() throws -> URL {
        guard let candidate = pythonCandidates.first(where: { FileManager.default.isExecutableFile(atPath: $0) }) else {
            throw PatchCourierMailTransportError.pythonNotFound
        }
        return URL(fileURLWithPath: candidate)
    }

    private var encoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.keyEncodingStrategy = .convertToSnakeCase
        return encoder
    }

    private var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return decoder
    }
}

private struct MailSendPayload: Encodable {
    var account: PatchCourierMailAccount
    var password: String
    var message: PatchCourierOutboundMailMessage
}

private struct MailHistoryPayload: Encodable {
    var account: PatchCourierMailAccount
    var password: String
    var limit: Int
}

private struct MailProbePayload: Encodable {
    var account: PatchCourierMailAccount
    var password: String
}

extension PatchCourierExecutionResult {
    static func parse(from message: PatchCourierInboundMailMessage) -> PatchCourierExecutionResult? {
        let body = message.plainBody
        let searchable = message.subject + "\n" + body
        let requestID = field("REQUEST_ID", in: searchable)
        let taskID = field("TASK_ID", in: searchable) ?? taskIDFromSubject(message.subject)
        guard requestID != nil || taskID != nil || searchable.localizedCaseInsensitiveContains("EVOMAP_EXECUTE") else {
            return nil
        }

        let finalAnswer = multilineField("FINAL_ANSWER_MARKDOWN", in: body)
            ?? sectionBody(title: "FINAL_ANSWER_MARKDOWN", in: body)
        return PatchCourierExecutionResult(
            requestID: requestID,
            taskID: taskID,
            status: field("STATUS", in: body),
            confidence: field("CONFIDENCE", in: body),
            needsUserInput: boolField("NEEDS_USER_INPUT", in: body),
            riskFlags: field("RISK_FLAGS", in: body),
            finalAnswerMarkdown: finalAnswer?.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty,
            rawBody: body,
            messageID: message.messageID,
            receivedAt: message.receivedAt,
            threadToken: threadToken(in: searchable)
        )
    }

    private static func field(_ name: String, in text: String) -> String? {
        let pattern = #"(?im)^\s*"# + NSRegularExpression.escapedPattern(for: name) + #"\s*:\s*(.+?)\s*$"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let match = regex.firstMatch(in: text, range: range),
              let valueRange = Range(match.range(at: 1), in: text) else {
            return nil
        }
        return String(text[valueRange]).trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty
    }

    private static func boolField(_ name: String, in text: String) -> Bool? {
        guard let value = field(name, in: text)?.lowercased() else { return nil }
        switch value {
        case "true", "yes", "y", "1", "是", "はい":
            return true
        case "false", "no", "n", "0", "否", "いいえ":
            return false
        default:
            return nil
        }
    }

    private static func multilineField(_ name: String, in text: String) -> String? {
        guard let markerRange = text.range(of: "\n\(name):", options: [.caseInsensitive])
            ?? text.range(of: "\(name):", options: [.caseInsensitive]) else {
            return nil
        }
        let start = markerRange.upperBound
        var value = String(text[start...])
        for footer in [
            "\nReply to this email",
            "\n如果你想让 Codex",
            "\n同じタスクを Codex"
        ] {
            if let footerRange = value.range(of: footer, options: [.caseInsensitive]) {
                value = String(value[..<footerRange.lowerBound])
            }
        }
        return value.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty
    }

    private static func sectionBody(title: String, in text: String) -> String? {
        let headings = ["\(title):", "\(title)："]
        for heading in headings {
            guard let range = text.range(of: heading, options: [.caseInsensitive]) else { continue }
            let value = String(text[range.upperBound...])
            return value.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty
        }
        return nil
    }

    private static func taskIDFromSubject(_ subject: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: #"\[EvoMap\]\[(?:EXECUTE|STATUS)\]\[([^\]]+)\]"#, options: [.caseInsensitive]) else {
            return nil
        }
        let range = NSRange(subject.startIndex..<subject.endIndex, in: subject)
        guard let match = regex.firstMatch(in: subject, range: range),
              let taskRange = Range(match.range(at: 1), in: subject) else {
            return nil
        }
        return String(subject[taskRange]).nonEmpty
    }

    private static func threadToken(in text: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: #"\[patch-courier:([^\]]+)\]"#, options: [.caseInsensitive]) else {
            return nil
        }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let match = regex.firstMatch(in: text, range: range),
              let tokenRange = Range(match.range(at: 1), in: text) else {
            return nil
        }
        return String(text[tokenRange]).nonEmpty
    }
}

private extension PatchCourierMailTransportClient {
    static var pythonScript: String {
        #"""
#!/usr/bin/env python3
import html
import imaplib
import json
import re
import smtplib
import ssl
import sys
from datetime import datetime, timezone
from email import policy
from email.message import EmailMessage
from email.parser import BytesParser
from email.utils import format_datetime, make_msgid, parseaddr, parsedate_to_datetime


def fail(message):
    print(message, file=sys.stderr)
    raise SystemExit(1)


def read_payload():
    raw = sys.stdin.buffer.read()
    if not raw:
        return {}
    return json.loads(raw.decode("utf-8"))


def normalize_date(raw_value):
    if not raw_value:
        return None
    try:
        parsed = parsedate_to_datetime(raw_value)
        if parsed.tzinfo is None:
            parsed = parsed.replace(tzinfo=timezone.utc)
        return parsed.astimezone(timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z")
    except Exception:
        return None


def extract_message_ids(raw_value):
    if not raw_value:
        return []
    return re.findall(r"<[^>]+>", raw_value)


def html_to_text(raw_html):
    text = re.sub(r"<br\s*/?>", "\n", raw_html, flags=re.IGNORECASE)
    text = re.sub(r"</p\s*>", "\n\n", text, flags=re.IGNORECASE)
    text = re.sub(r"<[^>]+>", " ", text)
    text = html.unescape(text)
    text = re.sub(r"\n{3,}", "\n\n", text)
    return text.strip()


def get_body_text(message):
    if message.is_multipart():
        plain_parts = []
        html_parts = []
        for part in message.walk():
            if part.get_content_disposition() == "attachment":
                continue
            content_type = part.get_content_type()
            try:
                content = part.get_content()
            except Exception:
                payload = part.get_payload(decode=True) or b""
                charset = part.get_content_charset() or "utf-8"
                content = payload.decode(charset, errors="replace")
            if content_type == "text/plain":
                plain_parts.append(str(content).strip())
            elif content_type == "text/html":
                html_parts.append(str(content))
        if plain_parts:
            return "\n\n".join([part for part in plain_parts if part]).strip()
        if html_parts:
            return "\n\n".join([html_to_text(part) for part in html_parts if part]).strip()
        return ""

    try:
        content = message.get_content()
    except Exception:
        payload = message.get_payload(decode=True) or b""
        charset = message.get_content_charset() or "utf-8"
        content = payload.decode(charset, errors="replace")

    if message.get_content_type() == "text/html":
        return html_to_text(str(content))
    return str(content).strip()


def connect_imap(account, password):
    imap_config = account["imap"]
    security = imap_config["security"]
    host = imap_config["host"]
    port = int(imap_config["port"])

    if security == "sslTLS":
        client = imaplib.IMAP4_SSL(host, port)
    else:
        client = imaplib.IMAP4(host, port)
        if security == "startTLS":
            client.starttls(ssl_context=ssl.create_default_context())

    client.login(account["email_address"], password)
    return client


def connect_smtp(account, password):
    smtp_config = account["smtp"]
    security = smtp_config["security"]
    host = smtp_config["host"]
    port = int(smtp_config["port"])

    if security == "sslTLS":
        client = smtplib.SMTP_SSL(host, port, timeout=30)
    else:
        client = smtplib.SMTP(host, port, timeout=30)
        client.ehlo()
        if security == "startTLS":
            client.starttls(context=ssl.create_default_context())
            client.ehlo()

    client.login(account["email_address"], password)
    return client


def decode_messages_by_uid(client, uids):
    messages = []
    for uid in uids:
        status, rows = client.uid("fetch", str(uid), "(BODY.PEEK[])")
        if status != "OK":
            continue

        raw_bytes = None
        for row in rows:
            if isinstance(row, tuple) and len(row) > 1:
                raw_bytes = row[1]
                break
        if raw_bytes is None:
            continue

        parsed = BytesParser(policy=policy.default).parsebytes(raw_bytes)
        sender_name, sender_address = parseaddr(parsed.get("From", ""))
        message_id = parsed.get("Message-ID") or f"<uid-{uid}@evomap-console.local>"
        references = []
        for header in parsed.get_all("References", []):
            references.extend(extract_message_ids(header))

        messages.append({
            "uid": uid,
            "messageID": message_id,
            "fromAddress": sender_address.lower(),
            "fromDisplayName": sender_name or None,
            "subject": parsed.get("Subject", "").strip(),
            "plainBody": get_body_text(parsed),
            "receivedAt": normalize_date(parsed.get("Date")) or normalize_date(parsed.get("Resent-Date")) or datetime.now(timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z"),
            "inReplyTo": parsed.get("In-Reply-To"),
            "references": references,
        })
    return messages


def fetch_history(payload):
    account = payload["account"]
    password = payload["password"]
    limit = max(1, min(int(payload.get("limit", 50)), 200))

    client = connect_imap(account, password)
    try:
        status, _ = client.select("INBOX")
        if status != "OK":
            fail("Could not open INBOX.")

        status, data = client.uid("search", None, "ALL")
        if status != "OK":
            fail("Could not search mailbox UIDs.")

        raw_uids = data[0].split() if data and data[0] else []
        uids = [int(item) for item in raw_uids]
        selected_uids = uids[-limit:]
        messages = decode_messages_by_uid(client, selected_uids)
        messages.sort(key=lambda item: item["uid"], reverse=True)
        return {"visibleCount": len(uids), "messages": messages}
    finally:
        try:
            client.logout()
        except Exception:
            pass


def send_message(payload):
    account = payload["account"]
    password = payload["password"]
    message_payload = payload["message"]

    message = EmailMessage()
    message["From"] = account["email_address"]
    message["To"] = ", ".join(message_payload["to"])
    message["Subject"] = message_payload["subject"]

    if message_payload.get("in_reply_to"):
        message["In-Reply-To"] = message_payload["in_reply_to"]

    references = message_payload.get("references") or []
    if references:
        message["References"] = " ".join(references)

    message_id = make_msgid(domain=account["email_address"].split("@")[-1])
    message["Date"] = format_datetime(datetime.now(timezone.utc))
    message["Message-ID"] = message_id
    message.set_content(message_payload["plain_body"])
    html_body = message_payload.get("html_body")
    if html_body and str(html_body).strip():
        message.add_alternative(str(html_body), subtype="html")

    client = connect_smtp(account, password)
    try:
        client.send_message(message)
    finally:
        try:
            client.quit()
        except Exception:
            pass

    return {"messageID": message_id}


def probe_connection(payload):
    account = payload["account"]
    password = payload["password"]
    address = account.get("email_address", "")

    imap_result = {"ok": False, "detail": "IMAP check did not run."}
    try:
        client = connect_imap(account, password)
        try:
            status, _ = client.select("INBOX")
            if status != "OK":
                raise RuntimeError("IMAP login succeeded, but INBOX could not be opened.")
            status, data = client.uid("search", None, "ALL")
            if status != "OK":
                raise RuntimeError("INBOX opened, but UID search failed.")
            visible_count = len(data[0].split()) if data and data[0] else 0
            imap_result = {"ok": True, "detail": f"IMAP login succeeded and INBOX is readable for {address} ({visible_count} visible message(s))."}
        finally:
            try:
                client.logout()
            except Exception:
                pass
    except Exception as err:
        imap_result = {"ok": False, "detail": str(err) or type(err).__name__}

    smtp_result = {"ok": False, "detail": "SMTP check did not run."}
    try:
        client = connect_smtp(account, password)
        try:
            client.noop()
            smtp_result = {"ok": True, "detail": f"SMTP login succeeded for {address}."}
        finally:
            try:
                client.quit()
            except Exception:
                pass
    except Exception as err:
        smtp_result = {"ok": False, "detail": str(err) or type(err).__name__}

    return {"imap": imap_result, "smtp": smtp_result}


def main():
    if len(sys.argv) < 2:
        fail("Expected a transport command.")

    try:
        payload = read_payload()
        command = sys.argv[1]
        if command == "history":
            result = fetch_history(payload)
        elif command == "send":
            result = send_message(payload)
        elif command == "probe":
            result = probe_connection(payload)
        else:
            fail(f"Unsupported command: {command}")
    except Exception as exc:
        fail(str(exc))

    print(json.dumps(result))


if __name__ == "__main__":
    main()
"""#
    }
}
