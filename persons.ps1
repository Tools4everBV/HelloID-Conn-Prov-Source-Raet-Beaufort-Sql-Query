$config = ConvertFrom-Json $configuration

# ODBC connection string
$connectionString = $config.connectionString;

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
        tpersoon.geb_dt, 
        tpersoon.w_straat, 
        tpersoon.w_huisnr,
        tpersoon.w_hnr_toev, 
        tpersoon.w_postcode, 
        tpersoon.w_plaats, 
        tpersoon.w_land_kd, 
        tpersoon.w_tel_nr, 
        tpersoon.mobiel_tel_nr, 
        tpersoon.werk_tel_nr, 
        tpersoon.email_werk, 
        tpersoon.email_prive 
    FROM 
        t4e_HelloID.dpib010 tpersoon
    "
    $persons = New-Object System.Collections.ArrayList
    Get-SQLData -connectionString $connectionString -SqlQuery $queryPersons -Data ([ref]$persons)
    Write-Verbose -Verbose "Person query completed";

    # SQL query for contracts
    $queryContracts = "SELECT
        tcontract.pers_nr,
        tcontract.dv_vlgnr,
        topdrgvr.opdrgvr_nr,
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
        t4e_HelloID.dpic300 tcontract  
        LEFT JOIN t4e_HelloID.dpib015 tafdeling ON tcontract.oe_hier_sl = tafdeling.dpib015_sl
        LEFT JOIN t4e_HelloID.dpib004 tkostenplaats ON tafdeling.kstpl_kd = tkostenplaats.kstpl_kd
        LEFT JOIN t4e_HelloID.dpic351 tfunctie ON tcontract.primfunc_kd = tfunctie.func_kd
        LEFT JOIN t4e_HelloID.dpic200 topdrgvr ON tcontract.OPDRGVR_NR = topdrgvr.OPDRGVR_NR 
    "
    $contracts = New-Object System.Collections.ArrayList
    Get-SQLData -connectionString $connectionString -SqlQuery $queryContracts -Data ([ref]$contracts)
    Write-Verbose -Verbose "Contract query completed";
    
    # Group the contracts
    Write-Verbose "Grouping contracts..." -Verbose
    $contracts = $contracts | Group-Object PERS_NR -AsHashTable

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
    foreach($person in $persons){
        # Add Contracts to person object
        if(-not([string]::IsNullOrEmpty($person.ExternalId))){
            $contractsPerson = $contracts[$person.ExternalId]
            if ( -not($null -eq $contractsPerson) ){
                $person.Contracts = $contractsPerson
            }
        }

        # Convert naming convention codes to standard
        Switch($person.GBRK_NAAM ){
            "E" {
                $person.GBRK_NAAM = "B"
            }
            "P" {
                $person.GBRK_NAAM = "P"
            }
            "C" {
                $person.GBRK_NAAM = "BP"
            }
            "B" {
                $person.GBRK_NAAM = "PB"
            }
            "D" {
                $person.GBRK_NAAM = "BP"
            }
        }

        # Export and sanitize the persons in json format
        $json = $person | ConvertTo-Json -Depth 10
        $json = $json.Replace("._", "__")
        Write-Output $json
    }
}catch{
    Write-Error $_
}