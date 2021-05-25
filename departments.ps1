$config = ConvertFrom-Json $configuration

# ODBC connection string
$connectionString = $($config.connectionString);
$managerTypeCode = $($config.managerTypeCode);

function Get-SQLData{
    param(
        [parameter(Mandatory=$true)]
        $connectionString,

        [parameter(Mandatory=$true)]
        $SqlQuery,

        [parameter(Mandatory=$true)]
        [ref]$Data
    )
    try{
        $Data.value = $null

        # Initialize connection and execute query
        # Connect to the SQL server
        $SqlConnection = New-Object System.Data.SqlClient.SqlConnection($ConnectionString);
        $SqlConnection.Open()
       
        Write-Verbose -Verbose "Successfully connected to SQL database" 

        # Set the query
        $SqlCmd = New-Object System.Data.SqlClient.SqlCommand;
        $SqlCmd.Connection = $SqlConnection;
        $SqlCmd.CommandText = $SqlQuery;

        # Set the data adapter
        $SqlAdapter = New-Object System.Data.SqlClient.SqlDataAdapter;
        $SqlAdapter.SelectCommand = $SqlCmd;

        # Set the output with returned data
        $DataSet = New-Object System.Data.DataSet;
        $null = $SqlAdapter.Fill($DataSet)

        # Set the output with returned data
        $Data.value =  $DataSet.Tables[0] | Select-Object -Property * -ExcludeProperty RowError, RowState, Table, ItemArray, HasErrors;
        Write-Verbose -Verbose "Successfully performed SQL query. Returned [$($DataSet.Tables[0].Columns.Count)] columns and [$($DataSet.Tables[0].Rows.Count)] rows"
        
    } catch {
        $Data.Value = $null
        Write-Error $_
    }finally{
        if($SqlConnection.State -eq "Open"){
            $SqlConnection.close()
        }
        Write-Verbose -Verbose "Successfully disconnected SQL Oracle database"
    }
}

try{
    # Get Department data
    $queryDepartments = "SELECT
        CAST(ou.dpib015_sl AS int) AS afdeling,
        ou.orgeenh_kd,
        ou.oe_kort_nm,
        ou.oe_vol_nm,
        CAST(ou.oe_hoger_n AS int) AS oe_hoger_n,
        CAST(m.pers_nr AS int) as pers_nr,
        m.rol_oe_kd
    FROM t4e_HelloID.dpib015 ou
        LEFT JOIN t4e_HelloID.dpib025 m ON m.dpib015_sl = ou.dpib015_sl
    WHERE (pers_nr IS NULL) OR (
        m.rol_oe_kd = '$managerTypeCode'
        AND m.ingang_dt < CURRENT_TIMESTAMP
        AND (m.eind_dt IS NULL OR m.eind_dt > CURRENT_TIMESTAMP)
    )
    "

    $departments = New-Object System.Collections.ArrayList
    Get-SQLData -connectionString $connectionString -SqlQuery $queryDepartments -Data ([ref]$departments)
    Write-Verbose -Verbose "Department import completed";

    # Extend the departments with required and additional fields
    Write-Verbose "Augmenting departments..." -Verbose
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
    }

    # Output the json
    $json = $departments | ConvertTo-Json -Depth 3
    Write-Output $json
}catch{
    Write-Error $_
}