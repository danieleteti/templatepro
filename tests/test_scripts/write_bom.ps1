$content = 'Duplicate variable "localvalue" in include mapping - (got: "}") at line 1 in file C:\DEV\templatepro\tests\test_scripts\test246_include_mapping_error_duplicate.tpro'
$utf8Bom = New-Object System.Text.UTF8Encoding $true
[System.IO.File]::WriteAllText('C:\DEV\templatepro\tests\test_scripts\test246_include_mapping_error_duplicate.tpro.expected.exception.txt', $content, $utf8Bom)
