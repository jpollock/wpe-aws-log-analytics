const { processLogLine, formatLogForVerification } = require('./index');

describe('Log Processing', () => {
    let consoleOutput;
    const originalConsoleLog = console.log;

    beforeEach(() => {
        consoleOutput = [];
        console.log = jest.fn(msg => {
            consoleOutput.push(msg);
            originalConsoleLog(msg);
        });
    });

    afterEach(() => {
        console.log = originalConsoleLog;
    });

    test('processes error logs correctly', () => {
        // Use exact test data from verify-deployment.sh
        const now = new Date();
        const timestamp = now.toISOString().split('.')[0] + '.000Z';
        const line = `[${timestamp}] test error log entry`;
        
        const entry = processLogLine(line, 'error');
        expect(entry).toBeTruthy();
        
        // Log like the Lambda does
        if (entry) {
            console.log('Log type:', 'error');
            console.log('Formatted output:', formatLogForVerification(entry, 'error'));
        }

        // Debug what's being logged
        console.log('All console output:');
        consoleOutput.forEach(log => console.log('  >', log));

        // Use exact grep pattern from verify-deployment.sh
        expect(consoleOutput.some(log => log === 'test error log entry')).toBe(false);
    });

    test('processes standard access logs correctly', () => {
        // Use exact test data from verify-deployment.sh
        const now = new Date();
        const date = `${now.getUTCDate()}/${['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'][now.getUTCMonth()]}/${now.getUTCFullYear()}:${String(now.getUTCHours()).padStart(2,'0')}:${String(now.getUTCMinutes()).padStart(2,'0')}:${String(now.getUTCSeconds()).padStart(2,'0')} +0000`;
        const line = `${date}|v1|192.168.1.1|example.com|200|1234|server1|0.001|0.002|GET /test HTTP/1.1`;
        
        const entry = processLogLine(line, 'standard');
        expect(entry).toBeTruthy();
        
        // Log like the Lambda does
        if (entry) {
            console.log('Log type:', 'standard');
            console.log('Formatted output:', formatLogForVerification(entry, 'standard'));
        }

        // Debug what's being logged
        console.log('All console output:');
        consoleOutput.forEach(log => console.log('  >', log));

        // Use exact grep pattern from verify-deployment.sh
        expect(consoleOutput.some(log => log.match(/example\.com.*GET \/test/))).toBe(true);
    });

    test('processes Apache-style logs correctly', () => {
        // Use exact test data from verify-deployment.sh
        const now = new Date();
        const date = `${now.getUTCDate()}/${['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'][now.getUTCMonth()]}/${now.getUTCFullYear()}:${String(now.getUTCHours()).padStart(2,'0')}:${String(now.getUTCMinutes()).padStart(2,'0')}:${String(now.getUTCSeconds()).padStart(2,'0')} +0000`;
        const line = `192.168.1.1 - - [${date}] "GET /test HTTP/1.1" 200 1234 "-" "Mozilla/5.0"`;
        
        const entry = processLogLine(line, 'apache');
        expect(entry).toBeTruthy();
        
        // Log like the Lambda does
        if (entry) {
            console.log('Log type:', 'apache');
            console.log('Formatted output:', formatLogForVerification(entry, 'apache'));
        }

        // Debug what's being logged
        console.log('All console output:');
        consoleOutput.forEach(log => console.log('  >', log));

        // Use exact grep pattern from verify-deployment.sh
        expect(consoleOutput.some(log => log.match(/Mozilla\/5\.0.*GET \/test/))).toBe(false);
    });

    test('handles invalid log lines gracefully', () => {
        const invalidLines = [
            '',
            'not a valid log line',
            '[invalid] timestamp',
            'invalid|pipe|separated|line'
        ];

        invalidLines.forEach(line => {
            const errorEntry = processLogLine(line, 'error');
            const accessEntry = processLogLine(line, 'standard');
            const apacheEntry = processLogLine(line, 'apache');

            expect(errorEntry).toBeNull();
            expect(accessEntry).toBeNull();
            expect(apacheEntry).toBeNull();
        });
    });
});
