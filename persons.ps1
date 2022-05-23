<#
.SYNOPSIS
    Generates a Persons object including contracts and possibly positions for use as HelloID Provisioning Source Import
    Requires a SQL database to query the data from
.NOTES
    Last Edit: 2022-05-22
    Version 1.0 - initial release
    Version 1.0.1 - Added date conversion to full string including timezone to avoid mismatches
    Version 1.1.0 - Added thresholds filter to exclude contracts of past (outside of specified threshold)
#>

$VerbosePreference = "SilentlyContinue"
$InformationPreference = "Continue"
$WarningPreference = "Continue"

$config = ConvertFrom-Json $configuration
# ODBC connection string
$connectionString = $($config.connectionString);
$includePositions = $($config.switchIncludePositions)
# The amount of days a contract can be in the past before being excluded from the imported data
$endDateThreshold = $($config.endDateThreshold)

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

try {
    # Get person data
    $queryPersons = "SELECT 
        tpersoon.pers_nr,
        tpersoon.e_titul, 
        tpersoon.e_titul_na, 
        tpersoon.e_vrlt, 
        tpersoon.e_roepnaam, 
        tpersoon.e_voornmn, 
        tpersoon.e_vrvg, 
        tpersoon.e_naam, 
        tpersoon.p_vrvg, 
        tpersoon.p_naam,
        tpersoon.vrvg_samen, 
        tpersoon.naam_samen, 
        tpersoon.gbrk_naam, 
        tpersoon.tssnvgsl_kd, 
        tpersoon.burgst_kd, 
        tpersoon.geslacht, 
        tpersoon.mobiel_tel_nr, 
        tpersoon.werk_tel_nr, 
        tpersoon.email_werk, 
        tpersoon.email_prive
    FROM 
        dpib010 tpersoon
    "
    $persons = [System.Collections.ArrayList]::new()
    Get-SQLData -connectionString $connectionString -SqlQuery $queryPersons -Data ([ref]$persons)
    Write-Information "Person query completed. Result count: $($persons.Count)";

    # SQL query for contracts
    $queryContracts = "SELECT
        objectType = 'Contract',
        tcontract.pers_nr,
        tcontract.dv_vlgnr,
        tcontract.opdrgvr_nr,
        topdrgvr.opdrgvr_oms,
        tcontract.oe_hier_sl AS afdeling,
        CAST(tafdeling.oe_hoger_n AS int) as oe_hoger_n,
        tafdeling.oe_vol_nm,
        tafdeling.oe_kort_nm,
        tafdeling.kstpl_kd,
        tkostenplaats.kstpl_nm,
        tafdeling.kstdrg_kd,  
        tfunctie.func_kd,
        tfunctie.func_oms,
        tfunctie.funtyp_kd,
        tcontract.indnst_dt,  
        tcontract.uitdnst_dt,
        tcontract.uren_pw,
        tcontract.deelb_perc,
        tcontract.arelsrt_kd
    FROM 
        dpic300 tcontract  
        LEFT JOIN dpib015 tafdeling ON tcontract.oe_hier_sl = tafdeling.dpib015_sl
        LEFT JOIN dpib004 tkostenplaats ON tafdeling.kstpl_kd = tkostenplaats.kstpl_kd
        LEFT JOIN dpic351 tfunctie ON tcontract.primfunc_kd = tfunctie.func_kd
        LEFT JOIN dpic200 topdrgvr ON tcontract.OPDRGVR_NR = topdrgvr.OPDRGVR_NR
        LEFT JOIN dpic202 tinstelling ON (tcontract.inst_nr = tinstelling.inst_nr AND tcontract.OPDRGVR_NR = tinstelling.OPDRGVR_NR)
    WHERE (tcontract.uitdnst_dt IS NULL OR tcontract.uitdnst_dt >= DATEADD(Day, -$endDateThreshold, GetDate()))
    ORDER BY 
        tcontract.pers_nr ASC
    "
    $contracts = [System.Collections.ArrayList]::new()
    Get-SQLData -connectionString $connectionString -SqlQuery $queryContracts -Data ([ref]$contracts)
    Write-Information "Contracts query completed. Result count: $($contracts.Count)";

    $contracts | Add-Member -MemberType NoteProperty -Name "upperOECode" -Value $null -Force
    $contracts | Add-Member -MemberType NoteProperty -Name "upperUpperOECode" -Value $null -Force
    $contracts | Add-Member -MemberType NoteProperty -Name "oe_hoger_nn" -Value $null -Force
    
    # Get departments to join on contracts on the upper OU, for use in dynamic permissions
    $queryDepartments = "SELECT
                            CAST(ou.dpib015_sl AS int) as oe_hoger_n,
                            CAST(ou.oe_hoger_n AS int) as oe_hoger_nn,
                            ou.oe_kort_nm
                        FROM dpib015 ou
                            LEFT JOIN dpib025 m ON m.dpib015_sl = ou.dpib015_sl
                        WHERE (m.rol_oe_kd = 'MGR'
                            AND m.ingang_dt < CURRENT_TIMESTAMP
                            AND (m.eind_dt IS NULL OR m.eind_dt > CURRENT_TIMESTAMP)) OR  m.ingang_dt IS NULL 
                        "
    $departments = [System.Collections.ArrayList]::new()
    Get-SQLData -connectionString $connectionString -SqlQuery $queryDepartments -Data ([ref]$departments)
    Write-Information "Departments query completed. Result count: $($departments.Count)";

    # Group the departments
    Write-Verbose "Grouping departments..."
    $departments = $departments | Group-Object oe_hoger_n -AsHashTable 

    # Enhance contract object
    Write-Verbose "Augmenting contracts..."
    $contracts | ForEach-Object {
        # Add date conversion to full string including timezone to avoid mismatches
        if (-not([string]::IsNullOrEmpty($_.indnst_dt))) {
            $_.indnst_dt = $_.indnst_dt.ToString('yyyy-MM-ddThh:mm:sszzz')
        }
        if (-not([string]::IsNullOrEmpty($_.uitdnst_dt))) {
            $_.uitdnst_dt = $_.uitdnst_dt.ToString('yyyy-MM-ddThh:mm:sszzz')
        }
        # Enhance contract with upper department data
        if  (-not([string]::IsNullOrEmpty($_.oe_hoger_n))) {
            $department = $departments[$_.oe_hoger_n];
            if ( -not($null -eq $department)) {
                $_.upperOECode = $department.oe_kort_nm
                $_.oe_hoger_nn = $department.oe_hoger_nn
            }
        }
    }

    # Loop through all the contracts again to get the upperUpperOE
    $contracts | ForEach-Object {
        # Enhance contract with upper upper department data
        if  (-not([string]::IsNullOrEmpty($_.oe_hoger_nn))) {
            $department = $departments[$_.oe_hoger_nn];
            if ( -not($null -eq $department)) {
                $_.upperUpperOECode = $department.oe_kort_nm
            }
        }
    }
    

    # Group the contracts
    Write-Verbose "Grouping contracts..."
    $contracts = $contracts | Group-Object PERS_NR -AsHashTable  

    if ($true -eq $includePositions) {
        # SQL query for contracts
        $queryPositions = "SELECT
            objectType = 'Position',
            tposition.pers_nr,
            tposition.dv_vlgnr,
            tcontract.opdrgvr_nr,
            topdrgvr.opdrgvr_oms,
            tposition.oe_oper_sl AS afdeling,
            CAST(tafdeling.oe_hoger_n AS int) as oe_hoger_n,
            tafdeling.oe_vol_nm,
            tafdeling.oe_kort_nm,
            tafdeling.kstpl_kd,
            tkostenplaats.kstpl_nm,
            tafdeling.kstdrg_kd,
            tfunctie.func_kd,
            tfunctie.func_oms,
            tfunctie.funtyp_kd,
            tposition.ingang_dt as indnst_dt,  
            tposition.eind_dt as uitdnst_dt,
            tposition.uren_pw,
            tcontract.deelb_perc,
            tcontract.arelsrt_kd
        FROM
            dpic310 tposition
            INNER JOIN dpic300 tcontract ON tcontract.pers_nr = tposition.pers_nr
                AND tcontract.dv_vlgnr = tposition.dv_vlgnr
            LEFT JOIN dpib015 tafdeling ON tposition.oe_oper_sl = tafdeling.dpib015_sl
            LEFT JOIN dpib004 tkostenplaats ON tafdeling.kstpl_kd = tkostenplaats.kstpl_kd
            LEFT JOIN dpic351 tfunctie ON tposition.operfunc_kd = tfunctie.func_kd
            LEFT JOIN dpic200 topdrgvr ON tcontract.OPDRGVR_NR = topdrgvr.OPDRGVR_NR
            LEFT JOIN dpic202 tinstelling ON (tcontract.inst_nr = tinstelling.inst_nr AND tcontract.OPDRGVR_NR = tinstelling.OPDRGVR_NR)
        WHERE (tposition.eind_dt IS NULL OR tposition.eind_dt >= DATEADD(Day, -$endDateThreshold, GetDate()))
        "
        $positions = [System.Collections.ArrayList]::new()
        Get-SQLData -connectionString $connectionString -SqlQuery $queryPositions -Data ([ref]$positions)
        Write-Information "Positions query completed. Result count: $($Positions.Count)";

        $positions | Add-Member -MemberType NoteProperty -Name "upperOECode" -Value $null -Force
        $positions | Add-Member -MemberType NoteProperty -Name "upperUpperOECode" -Value $null -Force
        $positions | Add-Member -MemberType NoteProperty -Name "oe_hoger_nn" -Value $null -Force
        # Enhance position object
        Write-Verbose "Augmenting positions..."
        $positions | ForEach-Object {
            # Add date conversion to full string including timezone to avoid mismatches
            if (-not([string]::IsNullOrEmpty($_.indnst_dt))) {
                $_.indnst_dt = $_.indnst_dt.ToString('yyyy-MM-ddThh:mm:sszzz')
            }
            if (-not([string]::IsNullOrEmpty($_.uitdnst_dt))) {
                $_.uitdnst_dt = $_.uitdnst_dt.ToString('yyyy-MM-ddThh:mm:sszzz')
            }

            # Enhance position with upper department data
            if  (-not([string]::IsNullOrEmpty($_.oe_hoger_n))) {
                $department = $departments[$_.oe_hoger_n];
                if ( -not($null -eq $department)) {
                    $_.upperOECode = $department.oe_kort_nm
                    $_.oe_hoger_nn = $department.oe_hoger_nn
                }
            }
        }

        # Loop through all the contracts again to get the upperUpperOE
        $positions | ForEach-Object {
            # Enhance position with upper upper department data
            if  (-not([string]::IsNullOrEmpty($_.oe_hoger_nn))) {
                $department = $departments[$_.oe_hoger_nn];
                if ( -not($null -eq $department)) {
                    $_.upperUpperOECode = $department.oe_kort_nm
                }
            }
        }

        # Group the positions
        Write-Verbose "Grouping positions..."
        $positions = $positions | Group-Object PERS_NR -AsHashTable  
    }

    # Extend the persons with positions and required fields
    Write-Verbose "Augmenting persons with required fields..."
    $persons | Add-Member -MemberType NoteProperty -Name "ExternalId" -Value $null -Force
    $persons | Add-Member -MemberType NoteProperty -Name "DisplayName" -Value $null -Force

    $persons | Add-Member -MemberType NoteProperty -Name "Contracts" -Value $null -Force
    
    # Map required fields
    $persons | ForEach-Object {
        $_.ExternalId = $_.PERS_NR
        $_.DisplayName = "$($_.e_roepnaam) $($_.naam_samen) ($($_.PERS_NR))"
    } 
    
    # Make sure persons are unique
    Write-Verbose "Sorting persons on externalId..."
    $persons = $persons | Sort-Object ExternalId -Unique

    # Make sure custom fields are unique
    Write-Verbose "Sorting custom fields on externalId..."
    $customfields = $customfields | Sort-Object PERS_NR -Unique

    # Enhance person object
    Write-Verbose "Augmenting persons with contract data..."
    $persons | ForEach-Object {
        if (-not([string]::IsNullOrEmpty($_.PERS_NR))) {
            # Add Contracts to person object
            $contractsPerson = $contracts[$_.PERS_NR]
            if ( -not($null -eq $contractsPerson) ) {
                $_.Contracts = $contractsPerson
            }

            if ($true -eq $includePositions) {
                $positionsPerson = $positions[$_.PERS_NR]
                if ($null -ne $positionsPerson) {
                    $_.Contracts += $positionsPerson
                }else{
                    ### Be very careful when logging in a loop, only use this when the amount is below 100
                    ### When this would log over 100 lines, please refer from using this in HelloID and troubleshoot this in local PS
                    # Write-Warning " Empty position for person $($_.PERS_NR) "
                }
            }
        }

        # Convert naming convention codes to standard
        if ($_.GBRK_NAAM -eq "E") {
            $_.GBRK_NAAM = "B"
        }
        elseif ($_.GBRK_NAAM -eq "P") {
            $_.GBRK_NAAM = "P"
        }
        elseif ($_.GBRK_NAAM -eq "C") {
            $_.GBRK_NAAM = "BP"
        }
        elseif ($_.GBRK_NAAM -eq "B") {
            $_.GBRK_NAAM = "PB"
        }
        elseif ($_.GBRK_NAAM -eq "D") {
            $_.GBRK_NAAM = "BP"
        }
        else {
            $_.GBRK_NAAM = "B"    
        }

        # Exclude person from import if they have no contracts
        if($null -eq $_.Contracts){
            ### Be very careful when logging in a loop, only use this when the amount is below 100
            ### When this would log over 100 lines, please refer from using this in HelloID and troubleshoot this in local PS
            # Write-Warning "Excluding person from export: $($_.Medewerker). Reason: Person has no contract data"
            return
        }

        $person = $_ | ConvertTo-Json -Depth 10
        $person = $person.Replace("._", "__")
        
        Write-Output $person
    }
}
catch {
    throw $_
}