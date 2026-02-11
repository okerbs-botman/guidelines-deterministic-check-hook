# C# Coding Standards

#### **Indentación**
- Usa **4 espacios** para la indentación en bloques, clases y estructuras de control.

```csharp
private static List<ULTIMO_CONCEPTO_CARGADO> UltimosConceptosCargados(ICollection<CONCEPTO_CARGADO_DETAIL_NOTMAPPED> detalleConceptos)
{
    List<ULTIMO_CONCEPTO_CARGADO> ultimosConceptos = [];
    if (detalleConceptos != null)
    {
        foreach (CONCEPTO_CARGADO_DETAIL_NOTMAPPED item in detalleConceptos)
        {
            ultimosConceptos.Add(new()
            {
                ID_CONCEPTO = item.ID_CONCEPTO.Value;
            });
        }
    }
    return ultimosConceptos;
}
```

#### **Atributos**
- No dejes líneas en blanco entre los atributos y el miembro que describen (clases, propiedades, métodos, etc.).

```csharp
namespace AxCloud.Model.Domain.Tesoreria
{
    [Table("SBA01")]
    [Title("Cuentas de Tesorería")]
    [DisplayLabel("Cuenta de Tesorería")]
    [ProcessLabel("Cuentas de Tesorería")]
    public class SBA01 : AdditionalFieldEntity
    {
        [Key]
        public int IDSBA01 { get; set; }
```

#### **Líneas finales**
- Agrega una línea en blanco al final de cada archivo.

```csharp
[Column(Order = 200)]
[StringTangoNullable]
[DisplayLabel("Observaciones")]
[StringLength(8000)]
public string OBSERVACIONES { get; set; }
// Línea en blanco obligatoria al final del archivo
```

#### **Base**
- Coloca la cláusula `: base(...)` en la línea siguiente cuando la firma del constructor o método sea extensa.

```csharp
public FeriadosAbm(IContext context,
    IEntityService<Domain.FERIADO> entityService,
    IEntityService<PARTE_DIARIO> parteDiarioService)
    : base(context, entityService)
{
    this.parteDiarioService = parteDiarioService;
}
```

#### **Herencia**
- Agrega un espacio en blanco antes y después del carácter `:` cuando una clase herede de otra.

```csharp
public class FeriadosAbm : AbmDomain.FERIADO
{
    // ...
}
```

#### **Constantes de tipo string**
- Usa constantes para valores string inmutables y reutilizados.

```csharp
public class TiposHoraAbm : Abm<Domain.TIPOHORA>
{
    private const string SinHora = "SINHORA";

    protected override void SetControlsDomain(int? idSinHora)
    {
        int? tipoHora = FirstOrDefault(p => p.COD_TIPO_HORA == SinHora)?.ID_TIPO_HORA;
        // ...
    }
}
```

#### **Siglas**
- Las siglas se escriben en mayúsculas y sin puntos.

```csharp
[StringLength(1)]
[StringTangoNullable]
[DisplayLabel("Controla vigencia certificado RG 1817")]
public string RG1817 { get; set; }
```

#### **Enumerados**
- Utiliza enumerados `YesNoEnum` (u otros específicos) para comparar contra valores como `S` o `N`.

```csharp
if (!entity.DIRECCION_ENTREGA.Any(p => p.HABITUAL == YesNoEnum.Si.Key))
{
    throw new DebeTenerDireccionHabitualException();
}
```

#### **Excepciones**
- Crea una clase de excepción específica para cada caso de negocio.

Correcto:

```csharp
using System;

namespace AxCloud.Modules.Fondos.Abm.CuentasTesoreria.Exceptions
{
    public class PlanTarjetaException : Exception
    {
        public PlanTarjetaException()
            : base("No es posible guardar el registro porque no existe el valor correspondiente en Planes de tarjetas.")
        {
        }
    }
}

if (item.IDSBA21 == null)
{
    throw new PlanTarjetaException();
}
```

Incorrecto:

```csharp
if (item.IDSBA21 == null)
{
    throw new Exception("No es posible guardar el registro");
}
```

#### **Métodos públicos**
- Incluye un bloque `<summary>` que describa la función.
- Documenta parámetros genéricos explicando qué representa cada tipo.

```csharp
/// <summary>
/// Determina si hay que rechazar el lote porque existen inconsistencias que afectan a todos los legajos.
/// </summary>
/// <param name="liquidaGanancias"></param>
/// <param name="hayDatosInconsistentesGanancias"></param>
public static bool BloqueaLiquidacionConcepto(bool liquidaGanancias, bool hayDatosInconsistentesGanancias)
{
    return liquidaGanancias && hayDatosInconsistentesGanancias;
}
```

#### **Código comentado**
- No subas código comentado al repositorio.

```csharp
protected override void SetRelatedProcesses(IList<RelatedProcess> relatedProcesses)
{
    AddRelatedProcess(relatedProcesses, GetDTOFichaLive, ActionConst.AcAccesoCuentas18574);
    AddRelatedProcess(relatedProcesses, AccesoParametrizacionContable, ActionConst.AcAccesoCuentas18190);
    // AddRelatedProcess(relatedProcesses, ActionConst.AcAccesoDefinicion18394); <-- No subir
}
```

#### **Revisar using**
- Elimina directivas `using` innecesarias.

```csharp
using System;
using AxCloud.Core.Control.Expressions;  // Si está dentro de System, elimina esta línea
```

#### **Condicionales**
- Usa llaves `{}` siempre, aunque el bloque contenga una sola línea.

```csharp
if (entity.ID_MONEDA == monedaCorriente)
{
    asignarMoneda = true;
}
else if (entity.ID_MONEDA == monedaAlternativaHabitual)
{
    asignarMoneda = true;
}
```

#### **Orden de visibilidad dentro de una clase**
1. `private`
2. `protected`
3. `public`

```csharp
private void ConfigureQueries(IList<QueryDto> queries)
{
    ExcludeColumnsFromDefaultSearch(queries);
}

private IList<JObject> RemovePropertiesNotInColumns(IList<JObject> jobjects, IList<Column> columns)
{
    // Implementación
}

protected bool HasAnyApertureMethod()
{
    return HasExcelCapability() || HasApiCapability() || IncludePrinteButton();
}

/// <summary>
/// Exporta una plantilla para su posterior importación. Solo funciona con Excel.
/// </summary>
/// <param name="addQueryData"></param>
/// <param name="filter"></param>
/// <param name="columns"></param>
/// <param name="configuration"></param>
/// <param name="context">Contexto de ejecución en el cliente.</param>
public ExportResult ExportTemplate(bool addQueryData, FilterRule filter, IList<Column> configuration, object context)
{
    InitializeProgressHandler(context, nameof(ExportTemplate));
    progressHandler.StartEndless();
    try
    {
        // Implementación
    }
    finally
    {
        progressHandler.Stop();
    }
}
```

#### **Métodos estáticos**
- Limita los métodos estáticos a clases helper.

```csharp
namespace AxCloud.Core.Control.Helper
{
    public static class PeriodHelper
    {
        #region Métodos de fechas
        public static DateTime GetInicioSemanaProxima()
        {
            return GetInicioSemanaActual().AddDays(7);
        }

        public static DateTime GetFinSemanaProxima()
        {
            return GetFinSemanaActual().AddDays(7);
        }
        #endregion
    }
}
```

#### **Código no usado**
- No incluyas código que no se utiliza.

```
private readonly IEntityService<GVAPARAMETROSPEDIDOSTIENDASCOBRO> formaCobroTiendaService;
private readonly IEntityService<CPA01> cpa01Service;
private readonly IEntityService<CPA02> cpa02Service;   <-- Quita la línea si "cpa02Service" no está en uso
// campo nunca usado: CPA02 CuentasTesoreriaAbm.cpa02Service

private readonly Lazy<PARAMETROGBL> parametrosAbm;
private readonly Lazy<GVA16> parametrosWizard;
private readonly Lazy<Domain.SBA01> defaultEntityAbm;
```

#### **Var**
- Evita el uso de `var` y tipea explícitamente para mejorar la legibilidad.

Correcto:

```csharp
ContainerRow row3 = UI.AddRow(mainContainer.GetContainer(tabPpalLabel), GetColumnsDefinition());
QuestionLookupFactory<MedidaLookup, int, string> medidaLookup =
    QuestionLookupFactory<MedidaLookup>.Create(p => p.AvailableFields.COD_MEDIDA, p => p.AvailableFields.ID_MEDIDA, countryCode);
UI.Controls.Add(p => p.ID_MEDIDA, row3, ContainerColumnPosition.first, medidaLookup);
QuestionRequiredBase descMedidaLookup = medidaLookup.GetLookupField(p => p.AvailableFields.DESC_MEDIDA);
UI.Controls.Add(row3, ContainerColumnPosition.second, descMedidaLookup);
```

Incorrecto:

```csharp
ContainerRow row3 = UI.AddRow(mainContainer.GetContainer(tabPpalLabel), GetColumnsDefinition());
var medidaLookup = QuestionLookupFactory<MedidaLookup>.Create(p => p.AvailableFields.COD_MEDIDA, p => p.AvailableFields.ID_MEDIDA, countryCode);
UI.Controls.Add(p => p.ID_MEDIDA, row3, ContainerColumnPosition.first, medidaLookup);
var descMedidaLookup = medidaLookup.GetLookupField(p => p.AvailableFields.DESC_MEDIDA);
UI.Controls.Add(row3, ContainerColumnPosition.second, descMedidaLookup);
```

#### **Archivos `.csproj`**
- Evita hacer commit de archivos `*.csproj` salvo que sea estrictamente necesario para el cambio.
