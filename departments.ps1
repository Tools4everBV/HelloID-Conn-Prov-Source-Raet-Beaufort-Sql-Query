<#
.SYNOPSIS
    Generates a Departments object for use as HelloID Provisioning Source Import
    Requires a SQL database to query the data from
.NOTES
    Last Edit: 2022-05-22
    Version 1.0 - initial release
    Version 1.0.1 - Updated logging
#>

$VerbosePreference = "SilentlyContinue"
$InformationPreference = "Continue"
$WarningPreference = "Continue"

$config = ConvertFrom-Json $configuration

# ODBC connection string
$connectionString = $($config.connectionString);
$managerTypeCode = $($config.managerTypeCode);

function Get-SQLData {
    param(
        [parameter(Mandatory = $true)]
        $connectionString,

        [parameter(Mandatory = $true)]
        $SqlQuery,

        [parameter(Mandatory = $true)]
        [ref]$Data
    )
    try {
        $Data.value = $null

        # Initialize connection and execute query
        # Connect to the SQL server
        $SqlConnection = [System.Data.SqlClient.SqlConnection]::new($ConnectionString);
        $SqlConnection.Open()
       
        Write-Verbose "Successfully connected to SQL database" 

        # Set the query
        $SqlCmd = [System.Data.SqlClient.SqlCommand]::new();
        $SqlCmd.Connection = $SqlConnection;
        $SqlCmd.CommandText = $SqlQuery;

        # Set the data adapter
        $SqlAdapter = [System.Data.SqlClient.SqlDataAdapter]::new();
        $SqlAdapter.SelectCommand = $SqlCmd;

        # Set the output with returned data
        $DataSet = [System.Data.DataSet]::new();
        $null = $SqlAdapter.Fill($DataSet)

        # Set the output with returned data
        $Data.value = $DataSet.Tables[0] | Select-Object -Property * -ExcludeProperty RowError, RowState, Table, ItemArray, HasErrors;
        Write-Verbose "Successfully performed SQL query. Returned [$($DataSet.Tables[0].Columns.Count)] columns and [$($DataSet.Tables[0].Rows.Count)] rows"
        
    }
    catch {
        $Data.Value = $null
        Write-Error $_
    }
    finally {
        if ($SqlConnection.State -eq "Open") {
            $SqlConnection.close()
        }
        Write-Verbose "Successfully disconnected from SQL database"
    }
}

try{
    # Get Department data
    $queryDepartments = "SELECT
        CAST(ou.dpib015_sl AS int) as afdeling,
        ou.orgeenh_kd,
        ou.oe_kort_nm,
        ou.oe_vol_nm,
        CAST(ou.oe_hoger_n AS int) as oe_hoger_n,
        CAST(m.pers_nr AS int) as pers_nr,
        m.rol_oe_kd,
        m.ingang_dt,
        m.eind_dt
    FROM dpib015 ou
        LEFT JOIN dpib025 m ON m.dpib015_sl = ou.dpib015_sl
    WHERE (m.rol_oe_kd = '$managerTypeCode'
        AND m.ingang_dt < CURRENT_TIMESTAMP
        AND (m.eind_dt IS NULL OR m.eind_dt > CURRENT_TIMESTAMP)) OR  m.ingang_dt IS NULL 
    "

    $departments = [System.Collections.ArrayList]::new()
    Get-SQLData -connectionString $connectionString -SqlQuery $queryDepartments -Data ([ref]$departments)
    Write-Information "Department query completed. Result count: $($perdepartmentsons.Count)";

    # Extend the departments with required and additional fields
    Write-Verbose "Augmenting departments..."
    $departments | Add-Member -MemberType NoteProperty -Name "ExternalId" -Value $null -Force
    $departments | Add-Member -MemberType NoteProperty -Name "DisplayName" -Value $null -Force
    $departments | Add-Member -MemberType NoteProperty -Name "Name" -Value $null -Force
    $departments | Add-Member -MemberType NoteProperty -Name "ManagerExternalId" -Value $null -Force
    $departments | Add-Member -MemberType NoteProperty -Name "ParentExternalId" -Value $null -Force
    $departments | ForEach-Object {
        $_.ExternalId = $_.afdeling
        $_.DisplayName = $_.oe_vol_nm
        $_.Name = $_.oe_vol_nm
        $_.ManagerExternalId = $_.pers_nr
        $_.ParentExternalId = $_.oe_hoger_n

        $department = $_ | ConvertTo-Json -Depth 10
        
        Write-Output $department

    }
}catch{
    throw $_
}