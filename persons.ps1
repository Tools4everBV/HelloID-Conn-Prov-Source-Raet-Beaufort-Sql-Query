$config = ConvertFrom-Json $configuration

# ODBC connection string
$connectionString = $($config.connectionString);
$includePositions = $($config.switchIncludePositions)

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
        $Data.value = $DataSet.Tables[0] | Select-Object -Property * -ExcludeProperty RowError, RowState, Table, ItemArray, HasErrors;
        Write-Verbose -Verbose "Successfully performed SQL query. Returned [$($DataSet.Tables[0].Columns.Count)] columns and [$($DataSet.Tables[0].Rows.Count)] rows"
        
    }
    catch {
        $Data.Value = $null
        Write-Error $_
    }
    finally {
        if ($SqlConnection.State -eq "Open") {
            $SqlConnection.close()
        }
        Write-Verbose -Verbose "Successfully disconnected from SQL database"
    }
}

try {
    # Get Department data
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
    $persons = New-Object System.Collections.ArrayList
    Get-SQLData -connectionString $connectionString -SqlQuery $queryPersons -Data ([ref]$persons)
    Write-Verbose -Verbose "Person query completed";

    # SQL query for contracts
    $queryContracts = "SELECT
        objectType = 'Contract',
        tcontract.pers_nr,
        tcontract.dv_vlgnr,
        tcontract.opdrgvr_nr,
        topdrgvr.opdrgvr_oms,
        tcontract.oe_hier_sl AS afdeling,
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
    "
    $contracts = New-Object System.Collections.ArrayList
    Get-SQLData -connectionString $connectionString -SqlQuery $queryContracts -Data ([ref]$contracts)
    Write-Verbose -Verbose "Contract query completed";
        
    # Group the contracts
    Write-Verbose "Grouping contracts..." -Verbose
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
        "
        $positions = New-Object System.Collections.ArrayList
        Get-SQLData -connectionString $connectionString -SqlQuery $queryPositions -Data ([ref]$positions)
        Write-Verbose -Verbose "Position query completed";

        # Group the positions
        Write-Verbose "Grouping positions..." -Verbose
        $positions = $positions | Group-Object PERS_NR -AsHashTable  
    }

    # Extend the persons with positions and required fields
    Write-Verbose "Augmenting persons with required fields..." -Verbose
    $persons | Add-Member -MemberType NoteProperty -Name "ExternalId" -Value $null -Force
    $persons | Add-Member -MemberType NoteProperty -Name "DisplayName" -Value $null -Force
    $persons | Add-Member -MemberType NoteProperty -Name "Contracts" -Value $null -Force
    # Map required fields
    $persons | ForEach-Object {
        $_.ExternalId = $_.PERS_NR
        $_.DisplayName = $_.PERS_NR
    } 
    
    # Make sure persons are unique
    Write-Verbose "Sorting persons on externalId..." -Verbose
    $persons = $persons | Sort-Object ExternalId -Unique

    # Enhance person object
    Write-Verbose "Augmenting persons with contract data..." -Verbose
    $persons | ForEach-Object {
        # Add Contracts to person object
        if (-not([string]::IsNullOrEmpty($_.PERS_NR))) {
            $contractsPerson = $contracts[$_.PERS_NR]
            if ( -not($null -eq $contractsPerson) ) {
                $_.Contracts = $contractsPerson
            }

            if ($true -eq $includePositions) {
                $positionsPerson = $positions[$_.PERS_NR]
                if ($null -ne $positionsPerson) {
                    $_.Contracts += $positionsPerson
                }
            }
        }
        
        # Convert naming convention codes to standard
        if($_.GBRK_NAAM -eq "E") {
            $_.GBRK_NAAM = "B"
        }elseif ($_.GBRK_NAAM -eq "P") {
            $_.GBRK_NAAM = "P"
        }elseif ($_.GBRK_NAAM -eq "C") {
            $_.GBRK_NAAM = "BP"
        }elseif ($_.GBRK_NAAM -eq "B") {
            $_.GBRK_NAAM = "PB"
        }elseif ($_.GBRK_NAAM -eq "D") {
            $_.GBRK_NAAM = "BP"
        }else{
            $_.GBRK_NAAM = "B"    
        }
    }

    # Filtering out persons without contracts
    #Write-Verbose "Filtering out persons without contract data..." -Verbose
    #$persons = $persons | Where-Object contracts -ne $null

    # Export and sanitize the persons in json format
    $json = $persons | ConvertTo-Json -Depth 10
    $json = $json.Replace("._", "__")
    Write-Output $json
}catch {
    Write-Error $_
}