#!/usr/bin/env python3
"""Analyze LSS network report exports and produce structured outputs."""

from __future__ import annotations

import json
import os
import re
import sys
from collections import defaultdict
from datetime import datetime
from urllib.parse import urlparse

SECTION_NAMES = {
    "Gateway",
    "Web Management Interfaces",
    "DNS Servers",
    "File Servers",
    "Printers",
}
IP_RE = re.compile(r"\b(?:\d{1,3}\.){3}\d{1,3}\b")
PORT_RE = re.compile(r"(\d+)")


def ensure_device(devices: dict, ip: str) -> dict:
    if ip not in devices:
        devices[ip] = {
            "ports": [],
            "services": {},
            "roles": [],
            "device_type": "unknown",
        }
    return devices[ip]


def add_port_service(device: dict, port: int | None, service: str | None = None) -> None:
    if port is None:
        return
    if port not in device["ports"]:
        device["ports"].append(port)
    if service:
        services = device["services"].setdefault(str(port), [])
        if service not in services:
            services.append(service)


def parse_report(report_file: str) -> tuple[dict, str | None]:
    devices: dict[str, dict] = {}
    gateway_ip: str | None = None
    current_section: str | None = None
    current_ip: str | None = None
    current_port: int | None = None

    with open(report_file, "r", encoding="utf-8", errors="ignore") as handle:
        for raw_line in handle:
            line = raw_line.strip()
            if not line:
                continue

            if line in SECTION_NAMES:
                current_section = line
                current_ip = None
                current_port = None
                continue

            if line.startswith("--- END ") and line.endswith(" SECTION ---"):
                current_section = None
                current_ip = None
                current_port = None
                continue

            if line.startswith("Gateway:"):
                found = IP_RE.search(line)
                if found:
                    gateway_ip = found.group(0)
                continue

            if current_section not in SECTION_NAMES:
                continue

            ip_match = None
            if line.startswith("IP:"):
                ip_match = IP_RE.search(line)
            elif IP_RE.fullmatch(line):
                ip_match = IP_RE.search(line)

            if ip_match:
                current_ip = ip_match.group(0)
                current_port = None
                device = ensure_device(devices, current_ip)
                role = current_section.lower().replace(" ", "_")
                if role not in device["roles"]:
                    device["roles"].append(role)
                continue

            if current_ip is None and current_section == "Web Management Interfaces" and (
                line.startswith("URL:") or line.startswith("http://") or line.startswith("https://")
            ):
                url = line.replace("URL:", "", 1).strip()
                parsed = urlparse(url)
                if parsed.hostname:
                    current_ip = parsed.hostname
                    device = ensure_device(devices, current_ip)
                    role = current_section.lower().replace(" ", "_")
                    if role not in device["roles"]:
                        device["roles"].append(role)
                    port = parsed.port or (443 if parsed.scheme == "https" else 80)
                    add_port_service(device, port, parsed.scheme or "http")
                continue

            if current_ip is None:
                continue

            device = ensure_device(devices, current_ip)

            if line.startswith("Port:"):
                port_match = PORT_RE.search(line)
                if port_match:
                    current_port = int(port_match.group(1))
                    add_port_service(device, current_port)
                continue

            if line.startswith("Service:"):
                service = line.split(":", 1)[1].strip()
                if current_port is not None:
                    add_port_service(device, current_port, service)
                continue

            if current_section == "Web Management Interfaces" and (
                line.startswith("URL:") or line.startswith("http://") or line.startswith("https://")
            ):
                url = line.replace("URL:", "", 1).strip()
                parsed = urlparse(url)
                port = parsed.port or (443 if parsed.scheme == "https" else 80)
                add_port_service(device, port, parsed.scheme or "http")

    for entry in devices.values():
        entry["ports"].sort()
        entry["roles"].sort()

    return devices, gateway_ip


def classify_devices(devices: dict[str, dict], gateway_ip: str | None) -> None:
    for ip, device in devices.items():
        ports = set(device["ports"])
        device_type = "unknown"

        if ports & {515, 9100}:
            device_type = "network_printer"
        if 53 in ports:
            device_type = "dns_server"
        if ports & {445, 139, 2049}:
            device_type = "file_server"
        if ports & {80, 443, 8443}:
            device_type = "web_interface_device"
        if ports == {22}:
            device_type = "ssh_host"
        if gateway_ip and ip == gateway_ip:
            device_type = "network_gateway"

        device["device_type"] = device_type


def write_outputs(devices: dict, analysis_file: str, devices_file: str, findings_file: str) -> None:
    with open(devices_file, "w", encoding="utf-8") as handle:
        json.dump(devices, handle, indent=2, sort_keys=True)

    type_counts = defaultdict(int)
    for data in devices.values():
        type_counts[data["device_type"]] += 1

    with open(analysis_file, "w", encoding="utf-8") as handle:
        handle.write("LSS Network Analysis Summary\n")
        handle.write("============================\n")
        handle.write(f"Total devices discovered: {len(devices)}\n")
        handle.write(f"DNS servers: {type_counts['dns_server']}\n")
        handle.write(f"Printers: {type_counts['network_printer']}\n")
        handle.write(f"File servers: {type_counts['file_server']}\n")
        handle.write(f"SSH hosts: {type_counts['ssh_host']}\n")
        handle.write(f"Web devices: {type_counts['web_interface_device']}\n")

    findings = {
        "Devices exposing DNS": sorted([ip for ip, d in devices.items() if 53 in d["ports"]]),
        "Devices exposing SMB": sorted(
            [ip for ip, d in devices.items() if ({445, 139} & set(d["ports"]))]
        ),
        "Devices exposing printer services": sorted(
            [ip for ip, d in devices.items() if ({515, 9100} & set(d["ports"]))]
        ),
        "Devices exposing SSH": sorted([ip for ip, d in devices.items() if 22 in d["ports"]]),
    }

    with open(findings_file, "w", encoding="utf-8") as handle:
        handle.write("LSS Security Findings\n")
        handle.write("=====================\n")
        for title, ips in findings.items():
            handle.write(f"\n{title}:\n")
            if ips:
                for ip in ips:
                    handle.write(f"- {ip}\n")
            else:
                handle.write("- None\n")


def main() -> int:
    if len(sys.argv) != 2:
        print("Usage: python3 lss-network-analyser.py <report_file>")
        return 1

    report_file = sys.argv[1]
    if not os.path.isfile(report_file):
        print(f"Error: report file not found: {report_file}")
        return 1

    report_dir = os.path.dirname(os.path.abspath(report_file))
    timestamp = datetime.now().strftime("%Y-%m-%d_%H-%M-%S")

    analysis_file = os.path.join(report_dir, f"LSS-NetInfo-Analysis-{timestamp}.txt")
    devices_file = os.path.join(report_dir, f"LSS-NetInfo-Devices-{timestamp}.json")
    findings_file = os.path.join(report_dir, f"LSS-NetInfo-Findings-{timestamp}.txt")

    devices, gateway_ip = parse_report(report_file)
    classify_devices(devices, gateway_ip)
    write_outputs(devices, analysis_file, devices_file, findings_file)

    print(f"Analysis summary written to: {analysis_file}")
    print(f"Device map written to: {devices_file}")
    print(f"Security findings written to: {findings_file}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
