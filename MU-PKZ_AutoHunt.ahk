; =========================================================================
; KHU VỰC HÀM KIỂM TRA BỘ NHỚ RAM HELPER GỐC (ĐÃ KHÔI PHỤC CHUẨN)
; =========================================================================
StartBuiltinHelper()
{
    global
    return true
}

IsBuiltinHelperActive()
{
    global
    return (ReadBuiltinHelperActive(active) && active)
}

StopBuiltinHelper()
{
    global
    if (!ReadBuiltinHelperActive(active))
        return false
    return true
}
