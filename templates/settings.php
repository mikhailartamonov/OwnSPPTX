<!DOCTYPE html>
<html>
<head>
    <title>Audio2Text Settings</title>
    <style>
        body {
            font-family: Arial, sans-serif;
            padding: 20px;
            max-width: 800px;
            margin: 0 auto;
        }
        h1 {
            color: #333;
        }
        .section {
            margin: 20px 0;
            padding: 15px;
            border: 1px solid #ddd;
            border-radius: 5px;
        }
        label {
            display: block;
            margin: 10px 0 5px 0;
            font-weight: bold;
        }
        input[type="text"], textarea {
            width: 100%;
            padding: 8px;
            border: 1px solid #ddd;
            border-radius: 3px;
            box-sizing: border-box;
        }
        textarea {
            min-height: 100px;
            font-family: monospace;
        }
        button {
            background: #0082c9;
            color: white;
            padding: 10px 20px;
            border: none;
            border-radius: 3px;
            cursor: pointer;
            margin: 5px;
        }
        button:hover {
            background: #006aa3;
        }
        .help-text {
            color: #666;
            font-size: 0.9em;
            margin-top: 5px;
        }
        .success {
            color: green;
            padding: 10px;
            background: #d4edda;
            border-radius: 3px;
            margin: 10px 0;
        }
        .error {
            color: red;
            padding: 10px;
            background: #f8d7da;
            border-radius: 3px;
            margin: 10px 0;
        }
    </style>
</head>
<body>
    <h1>Audio2Text - Administration</h1>

    <div id="message"></div>

    <div class="section">
        <h2>Access Control</h2>
        <label for="allowed-users">Allowed Users (one per line):</label>
        <textarea id="allowed-users" placeholder="Leave empty to allow all users&#10;Or enter usernames (one per line):&#10;mikhail.artamonov&#10;user2&#10;user3"></textarea>
        <div class="help-text">Leave empty to allow all users. Add usernames (one per line) to restrict access.</div>
    </div>

    <div class="section">
        <h2>Mattermost Integration</h2>
        <label for="mattermost-webhook">Mattermost Webhook URL:</label>
        <input type="text" id="mattermost-webhook" placeholder="https://mattermost.example.com/hooks/xxx">
        <div class="help-text">Leave empty to disable Mattermost notifications.</div>
    </div>

    <div class="section">
        <h2>Email Settings</h2>
        <label for="email-from">Email From Address:</label>
        <input type="text" id="email-from" placeholder="noreply@spbsot.ru">
        <div class="help-text">Email address used for sending notifications.</div>
    </div>

    <button onclick="saveSettings()">Save Settings</button>
    <button onclick="loadSettings()">Reload</button>

    <script>
        function loadSettings() {
            fetch('/index.php/apps/audio2text/settings/get', {
                method: 'GET',
                headers: {
                    'requesttoken': OC.requestToken
                }
            })
            .then(response => response.json())
            .then(data => {
                document.getElementById('allowed-users').value = data.allowed_users.join('\n');
                document.getElementById('mattermost-webhook').value = data.mattermost_webhook || '';
                document.getElementById('email-from').value = data.email_from || 'noreply@spbsot.ru';
            })
            .catch(error => {
                showMessage('Error loading settings: ' + error, 'error');
            });
        }

        function saveSettings() {
            const allowedUsers = document.getElementById('allowed-users').value
                .split('\n')
                .map(u => u.trim())
                .filter(u => u.length > 0);

            const settings = {
                allowed_users: allowedUsers,
                mattermost_webhook: document.getElementById('mattermost-webhook').value,
                email_from: document.getElementById('email-from').value
            };

            fetch('/index.php/apps/audio2text/settings/save', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                    'requesttoken': OC.requestToken
                },
                body: JSON.stringify(settings)
            })
            .then(response => response.json())
            .then(data => {
                if (data.success) {
                    showMessage('Settings saved successfully!', 'success');
                } else {
                    showMessage('Error saving settings', 'error');
                }
            })
            .catch(error => {
                showMessage('Error: ' + error, 'error');
            });
        }

        function showMessage(text, type) {
            const messageDiv = document.getElementById('message');
            messageDiv.className = type;
            messageDiv.textContent = text;
            setTimeout(() => {
                messageDiv.textContent = '';
                messageDiv.className = '';
            }, 5000);
        }

        // Load settings on page load
        document.addEventListener('DOMContentLoaded', loadSettings);
    </script>
</body>
</html>
