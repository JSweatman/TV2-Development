import os
DEFAULT_COUNTRY_CODE = os.getenv('DEFAULT_COUNTRY_CODE','1')
def namespace(raw: str, requested: str|None):
    value=raw.strip()
    if value.startswith('*'): return None,value[1:]
    if '*' in value:
        prefix,rest=value.split('*',1)
        if prefix.isdigit() and prefix: return prefix,rest
    return requested or DEFAULT_COUNTRY_CODE,value
