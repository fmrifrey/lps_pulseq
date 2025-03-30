function [kdata,seq_args] = gre3d_convert_data(safile,h5file)
% gets data from scanarchive file, and formats the kspace trajectories and
% sequence arguments based on seq_args.mat, then writes formatted data to
% h5 file for external recon if specified
% by David Frey (djfrey@umich.edu)
%
% inputs:
% safile - name of scanarchive file to read in
% h5file - name of output h5 file to write formatted data to (leave empty
% to not write to file)
%
% outputs:
% kdata - kspace data (Nx x Ny x Nz x ncoil)
% seq_args - struct containing pulse sequence arguments
%

    % get directory and file names
    d = dir(safile);
    sadir = d(1).folder;
    safile = d(1).name;
    
    % load in sequence arguments
    seq_args = load([sadir,'/seq_args.mat']);
    
    % load archive
    archive = GERecon('Archive.Load', safile);
    
    % get phase encode indicies
    pe_idcs = lpsutl.spout_caipi_idcs(seq_args.N, ...
        seq_args.Ry, seq_args.Rz, seq_args.Nacs);
    npe = length(pe_idcs);

    % skip past receive gain calibration TRs (pislquant)
    for n = 1:seq_args.pislquant
        currentControl = GERecon('Archive.Next', archive);
    end
    
    % loop through shots
    for i = 1:npe
        currentControl = GERecon('Archive.Next', archive);
        if i == 1
            [~,nc] = size(currentControl.Data);
            d1 = zeros(seq_args.N, nc, seq_args.N, seq_args.N);
        end
        d1(:,:,pe_idcs(i,1),pe_idcs(i,2)) = currentControl.Data;
    end
    
    % get kspace data
    kdata = permute(d1,[1,3,4,2]); % Nx x Ny x Nz x nc

    % save h5 file
    if nargin > 1 && ~isempty(h5file)

        if isfile(h5file)
            system(sprintf('rm %s',h5file));
        end

        % save kspace data
        h5create(h5file, '/kdata/real', size(kdata), ...
            'Datatype', class(real(kdata)));
        h5write(h5file, '/kdata/real', real(kdata));
        h5create(h5file, '/kdata/imag', size(kdata), ...
            'Datatype', class(imag(kdata)));
        h5write(h5file, '/kdata/imag', imag(kdata));

        % save sequence arguments
        seq_args_fields = fieldnames(seq_args);
        for i = 1:numel(seq_args_fields)
            field = seq_args_fields{i};
            val = seq_args.(field);
            if islogical(val)
                val = 1*val;
            end
            h5create(h5file, sprintf('/seq_args/%s',field), size(val), ...
                'Datatype', class(val));
            h5write(h5file, sprintf('/seq_args/%s',field), val)
        end

    end

end