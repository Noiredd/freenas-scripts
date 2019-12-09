import sys
content = sys.stdin.read()
formatter = '<html><body><pre>{}</pre></body></html>\n'
sys.stdout.write(formatter.format(content))
