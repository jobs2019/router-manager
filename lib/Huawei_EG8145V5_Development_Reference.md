# Huawei EG8145V5 Router Manager — Development Reference

## Purpose

This file is the project reference for future development of the Huawei EG8145V5 integration.

Use this document first before inspecting the Huawei router web files again.

The current project scope is intentionally limited to:

- Huawei login/session
- WAN Information
- Display WAN Name
- Display WAN Status
- Display WAN IP Address
- Display WAN VLAN ID

Currently SKIPPED:

- WAN creation/configuration
- PPPoE WAN creation
- Layer 2 configuration
- Layer 3 configuration
- Routing configuration
- Gateway/DNS/BRAS/MTU display unless explicitly requested later

---

# 1. Router

Model:

Huawei EG8145V5

Current router IP used during testing:

192.168.100.1

Web interface:

http://192.168.100.1

Huawei username used during testing:

telecomadmin

Do NOT store the real router password in this reference file.

---

# 2. Important Huawei WAN Endpoint

The confirmed WAN data endpoint is:

GET

/html/bbsp/common/wan_list_info.asp?<timestamp>

Example:

http://192.168.100.1/html/bbsp/common/wan_list_info.asp?36772

The browser's WAN Information page also uses this endpoint.

The request should include the authenticated Huawei session cookie and:

Referer:
http://192.168.100.1/html/bbsp/waninfo/waninfo.asp

Recommended headers:

Accept: */*
Accept-Language: en-GB,en-US;q=0.9,en;q=0.8
Connection: keep-alive
Cache-Control: no-cache
Pragma: no-cache

The endpoint was confirmed from the Chrome Network capture.

IMPORTANT:
Do not replace this endpoint with getwanlist.asp unless a future router firmware is proven to use it.

---

# 3. Huawei Login Flow

The existing application uses this flow:

1. GET:

/asp/GetRandCount.asp

2. Store the returned token.

3. Read the Set-Cookie header and store the Huawei session cookie.

4. POST:

/login.cgi

POST fields:

UserName
PassWord
Language
x.X_HW_Token

Password is Base64 encoded before being sent.

Language:

english

5. Save the new Set-Cookie value returned by login.cgi.

6. Use the resulting session cookie for WAN requests.

A WAN request returning:

top.location.replace('/')

means the Huawei session is no longer accepted and the application should report that the user needs to log in again.

---

# 4. Actual WAN Response Format

The confirmed Huawei response contains JavaScript objects like:

new WanPPP(
    "...",
    "...",
    ...
)

There can be multiple WanPPP objects.

The response is normally wrapped in something similar to:

var PPPWanList = new Array(
    new WanPPP(...),
    new WanPPP(...),
    new WanPPP(...),
    null
);

Therefore:

DO NOT parse only the first WAN.

DO NOT assume there is only one WAN.

DO NOT rely on a fixed number of WAN entries.

---

# 5. Confirmed WanPPP Field Map

The actual EG8145V5 WanPPP constructor was captured from the router web files.

Important fields:

| Index | Field | Application meaning |
|---:|---|---|
| 0 | domain | Internal Huawei WAN object path |
| 1 | X_HW_VXLAN_Enable | Not currently used |
| 2 | ConnectionTrigger | Not currently displayed |
| 3 | MACAddress | Not currently displayed |
| 4 | Status | WAN status |
| 5 | LastConnErr | Not currently displayed |
| 6 | RemoteWanInfo | Not currently displayed |
| 7 | Name | WAN name |
| 8 | Enable | Not currently displayed |
| 9 | EnableLanDhcp | Not currently displayed |
| 10 | DstIPForwardingList | Not currently displayed |
| 11 | ConnectionStatus | Not currently displayed |
| 12 | Mode | Not currently displayed |
| 13 | IPAddress | WAN IP address |
| 14 | Gateway | Available, but currently not displayed |
| 15 | NATEnable | Not currently displayed |
| 16 | X_HW_NatType | Not currently displayed |
| 17 | dnsstr | DNS information, currently not displayed |
| 18 | Username | PPPoE username, currently not displayed |
| 19 | Password | PPPoE password, do not display |
| 20 | DialMode | Not currently displayed |
| 21 | ConnectionControl | Not currently displayed |
| 22 | VlanId | VLAN ID |
| 23+ | Additional Huawei WAN fields | Not currently required |

CRITICAL:

For the actual WanPPP() structure:

- WAN Name = values[7]
- Status = values[4]
- IP Address = values[13]
- Gateway = values[14]
- DNS = values[17]
- VLAN ID = values[22]

Do NOT use the older incorrect mapping where VLAN was treated as index 15.

---

# 6. Huawei Escaped Values

Huawei encodes characters in the JavaScript response.

Examples:

\x3a = :
\x2e = .
\x5f = _
\x2d = -
\x40 = @
\x5c = \
\" = "

The parser must decode these before displaying values.

Examples:

1_INTERNET_R_VID_5

may arrive as:

1\x5fINTERNET\x5fR\x5fVID\x5f5

and:

F4\x3aB7\x3a8D\x3a0B\x3a0F\x3aEB

must become:

F4:B7:8D:0B:0F:EB

---

# 7. Parser Requirements

The WAN parser should:

1. Find every:

new WanPPP(

2. Extract the complete argument list.

3. Parse JavaScript quoted strings safely.

4. Decode Huawei \xNN escape sequences.

5. Map the fields using the confirmed indexes above.

6. Ignore empty/null objects.

7. Return all usable WAN objects.

A simple regex can work for the current response, but the safer implementation is:

- locate "new WanPPP("
- find the matching closing parenthesis while respecting quoted strings
- parse arguments
- convert the resulting fields

This avoids problems if future Huawei responses contain parentheses inside strings.

---

# 8. Current Application Data Model

The application should expose a simple WAN object with only the information currently required.

Recommended model:

class HuaweiWanInfo {
  final String domain;
  final String wanName;
  final String status;
  final String ipAddress;
  final String vlanId;

  const HuaweiWanInfo({
    required this.domain,
    required this.wanName,
    required this.status,
    required this.ipAddress,
    required this.vlanId,
  });
}

The API should return:

Future<List<HuaweiWanInfo>> getWanInformation()

If the current screen still uses Map<String, String>, keep the existing interface until there is a deliberate decision to migrate the screen.

---

# 9. Current WAN Display

The current screen should display only:

WAN Information

For each WAN:

Name
Status
IP Address
VLAN ID

Example:

1_INTERNET_R_VID_5
Status: Disconnected
IP Address: 0.0.0.0
VLAN ID: 5

2_INTERNET_R_VID_
Status: Connected
IP Address: 192.168.20.2
VLAN ID: -

3_INTERNET_R_VID_5
Status: Connecting
IP Address: 0.0.0.0
VLAN ID: 5

---

# 10. Untagged VLAN Display

Huawei may represent an untagged WAN with VLAN value:

0

or an empty VLAN field.

For the current UI:

0 / empty VLAN = -

Do not confuse this UI display with the raw Huawei value.

Keep the raw value internally if future features need it.

---

# 11. Confirmed Current Router WAN Data

The captured EG8145V5 WAN response contained three PPP WAN objects.

WAN 1:

Domain:
InternetGatewayDevice.WANDevice.1.WANConnectionDevice.1.WANPPPConnection.1

Name:
1_INTERNET_R_VID_5

Status:
Disconnected

IP:
0.0.0.0

VLAN:
5


WAN 2:

Domain:
InternetGatewayDevice.WANDevice.1.WANConnectionDevice.2.WANPPPConnection.1

Name:
2_INTERNET_R_VID_

Status:
Connected

IP:
192.168.20.2

Gateway:
192.168.20.1

VLAN:
0 / untagged


WAN 3:

Domain:
InternetGatewayDevice.WANDevice.1.WANConnectionDevice.3.WANPPPConnection.1

Name:
3_INTERNET_R_VID_5

Status:
Connecting

IP:
0.0.0.0

VLAN:
5

These values are evidence from the captured Huawei response, not assumptions.

---

# 12. Files That Matter

Main Flutter files:

lib/services/huawei_api.dart

lib/screens/huawei_test_screen.dart

Huawei source/reference files supplied during investigation:

wan_list_info.asp

wan_list.asp

waninfo.asp

The Huawei web files are reference material for understanding the router's JavaScript data structures.

The Dart API should be the only place that knows how to communicate with Huawei.

The screen should not contain Huawei parsing logic.

---

# 13. Architecture Rule

Use this separation:

Huawei router
    |
    v
HuaweiApi
    |
    v
HuaweiWanInfo
    |
    v
HuaweiTestScreen
    |
    v
UI

The screen should NOT:

- parse WanPPP()
- parse JavaScript
- decode \xNN values
- know Huawei field indexes
- construct Huawei HTTP requests

Those belong in huawei_api.dart.

---

# 14. Future Feature Rule

Before adding a new feature:

1. Check this reference file first.
2. Check whether the required endpoint/field is already documented.
3. Check whether the existing HuaweiApi already has the necessary session/authentication.
4. Only inspect the original Huawei ASP/JS files if the required information is NOT documented here.
5. Add any newly confirmed endpoint/field to this reference file immediately.
6. Do not repeatedly rediscover the same Huawei behavior.

---

# 15. Current Project Decision

The following features are intentionally NOT being developed now:

WAN configuration
PPPoE creation
Layer 2
Layer 3
Routing

Do not reintroduce these features unless explicitly requested.

The immediate stable target is:

LOGIN
+
WAN INFORMATION

---

# 16. Important Warning About Old Code

Several previous versions of huawei_api.dart contained conflicting WAN field mappings.

The confirmed mapping from the actual Huawei WanPPP constructor is:

Status = 4
Name = 7
IP Address = 13
Gateway = 14
DNS = 17
VLAN ID = 22

When old code conflicts with this document, verify against the actual captured WanPPP constructor before changing the mapping.

---

# 17. Debugging Checklist

If WAN information suddenly shows:

"No WAN connection was found"

check in this order:

1. Is Huawei login successful?
2. Is the session cookie still valid?
3. Does wan_list_info.asp return HTTP 200?
4. Does the response contain "new WanPPP("?
5. Are the WanPPP objects complete?
6. Are quoted JavaScript values being parsed correctly?
7. Are Huawei \xNN escapes being decoded?
8. Are there at least 23 parsed fields?
9. Are the indexes still:
   Status 4
   Name 7
   IP 13
   Gateway 14
   DNS 17
   VLAN 22
10. Only then inspect the screen.

---

# 18. Do Not Store Secrets Here

Never put these in this reference file:

- Huawei password
- PPPoE password
- Session cookie
- Authentication token
- Production credentials

Use placeholders when documenting examples.

---

# 19. Source of Truth

This reference was compiled from the actual EG8145V5 web resources and captured WAN response supplied during development.

Primary evidence:

- wan_list_info.asp — actual WanPPP data and constructor
- wan_list.asp — Huawei WAN naming/list behavior
- waninfo.asp — WAN Information page behavior
- Chrome Network capture — confirmed wan_list_info.asp request

Last confirmed project scope:

WAN Information only.

