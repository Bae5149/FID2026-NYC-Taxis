select *
from {{ ref('dq_reconciliation') }}
where
    filas_leidas is null
    or filas_limpias is null
    or filas_cuarentena is null
    or diferencia_filas is distinct from 0
    or filas_leidas != (filas_limpias + filas_cuarentena)
    or filas_limpias < 0
    or filas_cuarentena < 0