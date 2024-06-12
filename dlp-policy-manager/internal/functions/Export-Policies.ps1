function Export-Policies {
    [CmdletBinding()]
    <#
    .SYNOPSIS
    Exports a collection of policies to XML files in a specified directory.

    .DESCRIPTION
    Exports each policy in the provided array of policies to an XML file in the specified output directory. Each policy is saved as a separate XML file.

    .PARAMETER Policies
    An array of policy hashtables to export.

    .PARAMETER OutputPath
    The file path where the XML files should be saved.

    .EXAMPLE
    $policies = @(@{Name = "Policy1"; Data = "Data1"}, @{Name = "Policy2"; Data = "Data2"})
    Export-Policies -Policies $policies -OutputPath "C:\Policies"
    #>
    param (
        [array]$Policies,
        [string]$OutputPath
    )
    Begin {
        Write-Verbose "Creating output directory $OutputPath if it doesn't exist"
        New-Item -ItemType Directory -Path $OutputPath -Force -ErrorAction SilentlyContinue | Out-Null
    }
    Process {
        $Policies | ForEach-Object {
            $_ | Export-Clixml -Path "$OutputPath\$($_.Name).xml" -Depth 10
            Write-Verbose "Exported policy $($_.Name) to $OutputPath"
        }
    }
    End {
        Write-Verbose "All policies have been exported."
    }
}
