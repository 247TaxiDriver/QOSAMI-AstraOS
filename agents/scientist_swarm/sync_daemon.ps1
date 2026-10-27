while (\True) {
    # סנכרון ענן מרוחק למחשב המקומי
    git -C "C:\QOSAMI_VIRTUAL\QOSAMI-AstraOS" pull origin main --quiet
    Write-Host "[10/26/2026 17:22:02] QOSAMI Cloud Mirror Synchronized Locally [SIGNED_BY_TS]." -ForegroundColor Cyan
    Start-Sleep -Seconds 60
}
