<%@ page isELIgnored="true" contentType="text/html; charset=UTF-8" pageEncoding="UTF-8" %>
<%@ page import="java.util.*,java.net.*,java.io.*,java.time.*,java.time.format.DateTimeFormatter" %>
<%@ page import="org.springframework.web.util.HtmlUtils" %>
<%@ page import="software.amazon.awssdk.regions.Region" %>
<%@ page import="software.amazon.awssdk.core.client.config.ClientOverrideConfiguration" %>
<%@ page import="software.amazon.awssdk.services.elasticloadbalancingv2.ElasticLoadBalancingV2Client" %>
<%@ page import="software.amazon.awssdk.services.elasticloadbalancingv2.model.*" %>
<%!
    private volatile String cachedInstanceId = "";
    private volatile String cachedInstanceAz = "";

    private synchronized String currentInstanceAz() {
        if (!cachedInstanceAz.isEmpty()) return cachedInstanceAz;
        try {
            String token = metadata("api/token", null);
            String az = metadata("meta-data/placement/availability-zone", token);
            if (az.matches("ap-northeast-2[a-z]")) cachedInstanceAz = az;
        } catch (Exception ignored) {
        }
        return cachedInstanceAz.isEmpty() ? "AZ 조회 실패" : cachedInstanceAz;
    }

    private String esc(String value) {
        return HtmlUtils.htmlEscape(value == null ? "" : value);
    }

    private String shortId(String value) {
        return value == null ? "" :
            value.substring(Math.max(0, value.length() - 5));
    }

    private String stateClass(String state) {
        if ("healthy".equals(state)) return "healthy";
        if ("unhealthy".equals(state)) return "unhealthy";
        return "other";
    }

    private String metadata(String path, String token) throws IOException {
        HttpURLConnection connection = (HttpURLConnection)
            new URL("http://169.254.169.254/latest/" + path)
                .openConnection(Proxy.NO_PROXY);

        connection.setConnectTimeout(1000);
        connection.setReadTimeout(1000);

        if (token == null) {
            connection.setRequestMethod("PUT");
            connection.setRequestProperty(
                "X-aws-ec2-metadata-token-ttl-seconds", "60");
        } else {
            connection.setRequestProperty(
                "X-aws-ec2-metadata-token", token);
        }

        try {
            int status = connection.getResponseCode();
            if (status != 200) {
                throw new IOException("Metadata HTTP " + status);
            }
            try (BufferedReader reader = new BufferedReader(
                    new InputStreamReader(
                        connection.getInputStream(), "UTF-8"))) {
                String line = reader.readLine();
                return line == null ? "" : line.trim();
            }
        } finally {
            connection.disconnect();
        }
    }

    private synchronized String currentInstanceId() {
        if (!cachedInstanceId.isEmpty()) return cachedInstanceId;
        try {
            String token = metadata("api/token", null);
            String id = metadata("meta-data/instance-id", token);
            if (id.matches("i-[0-9a-f]+")) cachedInstanceId = id;
        } catch (Exception ignored) {
            // 조회 실패 시 다른 EC2에 임의로 연결하지 않는다.
        }
        return cachedInstanceId;
    }
%>
<%
    response.setHeader("Cache-Control", "no-store, max-age=0");
    response.setHeader("Pragma", "no-cache");

    String webInstanceId = request.getHeader("X-Demo-Web-Instance-ID");
    if (webInstanceId == null) webInstanceId = "";
    webInstanceId = webInstanceId.trim();

    String wasInstanceId = currentInstanceId();
    String wasAz = currentInstanceAz();
    String webAz = request.getHeader("X-Demo-Web-AZ");
    if (webAz == null || webAz.trim().isEmpty()) webAz = "AZ 미전달";

    String webAlbIp = request.getHeader("X-Demo-Web-Alb-IP");
    if (webAlbIp == null || webAlbIp.trim().isEmpty()) {
        webAlbIp = "IP 미전달";
    }

    String clientIp = "IP 미전달";
    String cloudFrontIp = "IP 미전달";
    String webIp = "IP 미전달";
    String forwardedFor = request.getHeader("X-Forwarded-For");

    if (forwardedFor != null && !forwardedFor.trim().isEmpty()) {
        String[] ips = forwardedFor.split(",");
        clientIp = ips[0].trim();
        if (ips.length >= 3) cloudFrontIp = ips[1].trim();
        webIp = ips[ips.length - 1].trim();
    }

    String[] arns = {
        "arn:aws:elasticloadbalancing:ap-northeast-2:430118836918:targetgroup/pet-prod-web-alb-tg/ab13cc940eb58eda",
        "arn:aws:elasticloadbalancing:ap-northeast-2:430118836918:targetgroup/pet-prod-was-arm-tg/2eccc541c1e5f14a"
    };

    List<List<TargetHealthDescription>> groups =
        new ArrayList<List<TargetHealthDescription>>();
    groups.add(new ArrayList<TargetHealthDescription>());
    groups.add(new ArrayList<TargetHealthDescription>());

    String[] errors = {"", ""};

    try (ElasticLoadBalancingV2Client client =
            ElasticLoadBalancingV2Client.builder()
                .region(Region.AP_NORTHEAST_2)
                .overrideConfiguration(
                    ClientOverrideConfiguration.builder()
                        .apiCallTimeout(Duration.ofSeconds(8))
                        .apiCallAttemptTimeout(Duration.ofSeconds(3))
                        .build())
                .build()) {

        for (int i = 0; i < arns.length; i++) {
            try {
                groups.get(i).addAll(client.describeTargetHealth(
                    DescribeTargetHealthRequest.builder()
                        .targetGroupArn(arns[i])
                        .build()).targetHealthDescriptions());

                Collections.sort(groups.get(i),
                    new Comparator<TargetHealthDescription>() {
                        public int compare(TargetHealthDescription a,
                                           TargetHealthDescription b) {
                            return a.target().id()
                                .compareTo(b.target().id());
                        }
                    });
            } catch (Exception e) {
                errors[i] = "타겟 상태 조회 실패";
                application.log("whoami target health query failed", e);
            }
        }
    } catch (Exception e) {
        errors[0] = errors[1] = "AWS 연결 실패";
        application.log("whoami AWS client failed", e);
    }

    String timestamp = ZonedDateTime.now(ZoneId.of("Asia/Seoul"))
        .format(DateTimeFormatter.ofPattern(
            "yyyy-MM-dd HH:mm:ss 'KST'"));
%>
<!DOCTYPE html>
<html lang="ko">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>서버 연결 현황</title>
<style>
    * { box-sizing: border-box; }
    body {
        margin: 0;
        background: #f6f8fb;
        color: #18202d;
        font-family: Arial, sans-serif;
    }
    main {
        max-width: 1800px;
        margin: auto;
        padding: 30px 24px;
    }
    header {
        position: relative;
        text-align: center;
        padding: 4px 120px 24px;
    }
    h1 { margin: 0 0 10px; font-size: 30px; }
    time { color: #778191; font-size: 14px; }
    button {
        position: absolute;
        right: 0;
        top: 4px;
        padding: 11px 18px;
        border: 1px solid #d6dce5;
        border-radius: 10px;
        background: white;
        color: #263246;
        font-size: 14px;
        cursor: pointer;
    }
    .viewport {
        overflow-x: auto;
        padding: 12px 0 22px;
    }
    .circuit {
        position: relative;
        display: grid;
        grid-template-columns: repeat(6, minmax(155px, 1fr));
        gap: 46px;
        align-items: center;
        min-width: 1250px;
        min-height: 430px;
        padding: 26px 4px;
    }
    .wires {
        position: absolute;
        inset: 0;
        width: 100%;
        height: 100%;
        pointer-events: none;
        z-index: 0;
        overflow: visible;
    }
    .column {
        position: relative;
        z-index: 1;
        display: flex;
        flex-direction: column;
        gap: 24px;
    }
    .card {
        width: 100%;
        min-height: 110px;
        padding: 20px 10px;
        border: 3px solid #242424;
        border-radius: 13px;
        background: #fff;
        text-align: center;
        box-shadow: 0 4px 12px rgba(20, 30, 45, .04);
    }
    .card h2 { margin: 0 0 12px; font-size: 18px; }
    .value {
        font-family: monospace;
        font-size: 20px;
        font-weight: bold;
        overflow-wrap: anywhere;
    }
    .status {
        margin-top: 10px;
        font-size: 14px;
        font-weight: bold;
    }
    .healthy { border-color: #20a444; }
    .healthy .status { color: #178536; }
    .unhealthy { border-color: #e63c43; }
    .unhealthy .status { color: #d22c34; }
    .other { border-color: #d5a326; }
    .other .status { color: #9a7314; }
    .current {
        background: #505762;
        color: #fff;
        border-color: #505762;
    }
    .client-icon {
        display: block;
        margin: 0 auto 10px;
    }
    .first-column {
        display: grid;
        grid-template-columns: 1fr;
        gap: 30px;
        align-content: center;
    }
    .first-column .spacer {
        height: var(--client-height, 160px);
        visibility: hidden;
    }
    .message {
        padding: 18px 10px;
        border: 1px solid #d6dce5;
        border-radius: 10px;
        background: #fff;
        text-align: center;
        color: #7a3540;
        font-size: 14px;
    }
    @media (max-width: 700px) {
        main { padding: 22px 14px; }
        header { text-align: left; padding: 0 110px 24px 0; }
        h1 { font-size: 23px; }
        time { font-size: 12px; }
    }
    #client { border-color: #ed8b23; }
    #client .client-icon circle, #client .client-icon path { stroke: #ed8b23; }
    #cloudfront { border-color: #8c4fff; }
    .card { min-height: 98px; padding: 16px 9px; border-radius: 11px; }
    .card h2 { font-size: 17px; margin-bottom: 9px; }
    .value { font-size: 19px; }
    .status { margin-top: 8px; font-size: 13px; }
    .column { gap: 26px; }
    .first-column { gap: 24px; }
    .circuit { gap: 54px; }
</style>
</head>
<body>
<main>
    <header>
        <h1>서버 연결 현황</h1>
        <time><%= esc(timestamp) %></time>
        <button type="button" onclick="location.reload()">새로고침</button>
    </header>

    <div class="viewport">
        <div class="circuit" id="circuit">
            <svg class="wires" id="wires" aria-hidden="true"></svg>

            <div class="column first-column" id="first-column">
                <div class="card" id="client">
                    <svg class="client-icon" width="38" height="42"
                         viewBox="0 0 38 42" aria-hidden="true">
                        <circle cx="19" cy="10" r="7" fill="none"
                                stroke="#202020" stroke-width="2.5"/>
                        <path d="M5 39v-5c0-8 6-13 14-13s14 5 14 13v5"
                              fill="none" stroke="#202020"
                              stroke-width="2.5" stroke-linecap="round"/>
                    </svg>
                    <h2>Client</h2>
                    <div class="value"><%= esc(clientIp) %></div>
                </div>
                <div class="card" id="cloudfront">
                    <img src="https://awsfundamentals.com/assets/aws-icons/Arch_Amazon-CloudFront_64.svg"
                         alt="Amazon CloudFront" width="40" height="40"
                         style="display:block;margin:0 auto 8px;">
                    <h2>CloudFront</h2>
                    <div class="value"><%= esc(cloudFrontIp) %></div>
                </div>
                <div class="card" id="web-alb">
                    <h2>Web ALB</h2>
                    <div class="value"><%= esc(webAlbIp) %></div>
                </div>
                <div class="spacer" aria-hidden="true"></div>
            </div>

            <div class="column" id="web-targets">
                <% if (!errors[0].isEmpty()) { %>
                    <div class="message"><%= esc(errors[0]) %></div>
                <% } else if (groups.get(0).isEmpty()) { %>
                    <div class="message">등록된 EC2 없음</div>
                <% } %>
                <% for (TargetHealthDescription target : groups.get(0)) {
                    String id = target.target().id();
                    String state = target.targetHealth().stateAsString();
                %>
                    <div class="card target <%= stateClass(state) %>"
                         data-current="<%= id.equals(webInstanceId) %>"
                         title="<%= esc(id) %>">
                        <h2>Web EC2</h2>
                        <div class="value"><%= esc(shortId(id)) %></div>
                        <div class="status"><%= esc(state) %></div>
                    </div>
                <% } %>
            </div>

            <div class="column">
                <div class="card" id="web-ip">
                    <h2>현재 Web EC2 IP</h2>
                    <div class="value"><%= esc(webIp) %></div>
                    <div class="status"><%= esc(webAz) %></div>
                </div>
            </div>

            <div class="column">
                <div class="card" id="was-alb">
                    <h2>WAS ALB</h2>
                    <div class="value"><%= esc(request.getRemoteAddr()) %></div>
                </div>
            </div>

            <div class="column" id="was-targets">
                <% if (!errors[1].isEmpty()) { %>
                    <div class="message"><%= esc(errors[1]) %></div>
                <% } else if (groups.get(1).isEmpty()) { %>
                    <div class="message">등록된 EC2 없음</div>
                <% } %>
                <% for (TargetHealthDescription target : groups.get(1)) {
                    String id = target.target().id();
                    String state = target.targetHealth().stateAsString();
                %>
                    <div class="card target <%= stateClass(state) %>"
                         data-current="<%= id.equals(wasInstanceId) %>"
                         title="<%= esc(id) %>">
                        <h2>WAS EC2</h2>
                        <div class="value"><%= esc(shortId(id)) %></div>
                        <div class="status"><%= esc(state) %></div>
                    </div>
                <% } %>
            </div>

            <div class="column">
                <div class="card current" id="was-ip">
                    <h2>현재 WAS IP</h2>
                    <div class="value"><%= esc(request.getLocalAddr()) %></div>
                    <div class="status"><%= esc(wasAz) %></div>
                </div>
            </div>
        </div>
    </div>
</main>

<script>
(function () {
    const board = document.getElementById('circuit');
    const svg = document.getElementById('wires');
    const ns = 'http://www.w3.org/2000/svg';

    function point(element, side) {
        const rect = element.getBoundingClientRect();
        const base = board.getBoundingClientRect();
        return {
            x: (side === 'right' ? rect.right : rect.left) - base.left,
            y: rect.top + rect.height / 2 - base.top
        };
    }

    function addPath(d, color) {
        const path = document.createElementNS(ns, 'path');
        path.setAttribute('d', d);
        path.setAttribute('fill', 'none');
        path.setAttribute('stroke', color || '#202020');
        path.setAttribute('stroke-width', '2');
        path.setAttribute('stroke-linecap', 'round');
        path.setAttribute('stroke-linejoin', 'round');
        svg.appendChild(path);
    }

    function connect(from, to) {
        if (!from || !to) return;

        const a = point(from, 'right');
        const b = point(to, 'left');
        const middle = (a.x + b.x) / 2;
        const delta = b.y - a.y;
        const radius = Math.min(
            12, Math.abs(delta) / 2, Math.max(0, (b.x - a.x) / 4));

        if (Math.abs(delta) < 1) {
            addPath('M ' + a.x + ' ' + a.y + ' H ' + b.x);
        } else {
            const direction = Math.sign(delta);
            addPath(
                'M ' + a.x + ' ' + a.y +
                ' H ' + (middle - radius) +
                ' Q ' + middle + ' ' + a.y +
                ' ' + middle + ' ' + (a.y + direction * radius) +
                ' V ' + (b.y - direction * radius) +
                ' Q ' + middle + ' ' + b.y +
                ' ' + (middle + radius) + ' ' + b.y +
                ' H ' + b.x
            );
        }
    }

    function draw() {
        const client = document.getElementById('client');
        const firstColumn = document.getElementById('first-column');

        firstColumn.style.setProperty(
            '--client-height', (client.offsetHeight + document.getElementById('cloudfront').offsetHeight + 24) + 'px');

        while (svg.firstChild) svg.removeChild(svg.firstChild);
        svg.setAttribute(
            'viewBox', '0 0 ' + board.clientWidth + ' ' + board.clientHeight);

        const webAlb = document.getElementById('web-alb');
        const webIp = document.getElementById('web-ip');
        const wasAlb = document.getElementById('was-alb');
        const wasIp = document.getElementById('was-ip');

        const base = board.getBoundingClientRect();
        const clientRect = client.getBoundingClientRect();
        const albRect = webAlb.getBoundingClientRect();
        const x = clientRect.left + clientRect.width / 2 - base.left;

        addPath(
            'M ' + x + ' ' + (clientRect.bottom - base.top) +
            ' V ' + (albRect.top - base.top), '#8c4fff'
        );

        document.querySelectorAll('#web-targets .target').forEach(card => {
            connect(webAlb, card);
            if (card.dataset.current === 'true') connect(card, webIp);
        });

        connect(webIp, wasAlb);

        document.querySelectorAll('#was-targets .target').forEach(card => {
            connect(wasAlb, card);
            if (card.dataset.current === 'true') connect(card, wasIp);
        });
    }

    window.addEventListener('load', draw);
    window.addEventListener('resize', draw);
    if (window.ResizeObserver) {
        new ResizeObserver(draw).observe(board);
    }
})();
</script>
</body>
</html>
