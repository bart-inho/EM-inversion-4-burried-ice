% simple 1D inversion of FDEM data acquired over a layered Earth using
% multiple coil separations and both vertical and horizontal dipoles

clear; clc; close all; tic
% load the dataset
load data2D

xlog = unique(data(:,4)); % horizontal size of the model
ztop = 0:.5:10; % vertical size of the model
nx = length(xlog); % number of discretization layers horizontal
nz = length(ztop); % number of discretization layers vertical
ndata = size(data,1); % number of sigma_a

% add Gaussian noise (JI: I changed this a bit to have some options)
nperc = 5;  % noise level in percent
rng(99999); % set random number seed to have consistent noise
d = data(:,1); % apparent conductivity data
nstd = (nperc/100)*abs(d);                          % noise with a variable standard deviation equal to X% of each data value
%nstd = (nperc/100)*repmat(mean(abs(d)),ndata,1);   % noise with a constant standard deviation equal to X% of mean data value
noise = nstd.*randn(size(d));
d = d + noise;
data(:,1) = d;

% set parameters for the regularization
% alphax should generally be much bigger than alphaz for layered media
alphas = .1;  % weight on model smallness relative to reference model (see inversion notes)
m0 = 0.02*ones(nx*nz,1); % reference constant conductivity model (not considered if alphas=0)
alphax = 10; % weight on model smoothness in x-direction
alphaz = 1;  % weight on model smoothness in z-direction
% set reference model

% calculate data and model weighting matrices
L = spdiags(1./nstd,0,ndata,ndata); %JI: added data weighting matrix to account for noise characteristics (see inversion notes)
Wd = L'*L;  
[Dx,Dz] = smoothweightEM2D(nx,nz);
Wm = alphas*speye(length(m0)) + alphax*(Dx'*Dx) + alphaz*(Dz'*Dz);

% inversion parameters knowing that lambda
lamb = logspace(3, 7, 1e2); % trade-off parameter
% lamb = 10;
tol = 1e-10; % tolerance for conjugate gradient solver
itmax = 500; % maximum # of iterations

chi2_tot = zeros(size(lamb));
R1D_tot = zeros(size(lamb));
m_tot = cell(size(lamb));
A_tot = cell(size(lamb));
G_tot = cell(size(lamb));

for s = 1:length(lamb)
    [m, m1, G, A] = inversionEM2D(ztop, nz, nx, data, lamb(s), Wm, Wd, m0, tol, itmax);
    
    % chi2
    chi2 = sum(((G*m1-d)./nstd).^2)./length(d);
    R = norm(Wm*m1).^2;    
    
    % store datas
    chi2_tot(:,s) = chi2;
    R1D_tot(:, s) = diag(R);
    m_tot{s} = m;
    A_tot{s} = A;
    G_tot{s} = G;
end

% Find best lambda index
b_chi2value = .85;
dchi2 = abs(b_chi2value - chi2_tot);
ilambda = find(dchi2==min(dchi2));
lambda = lamb(ilambda);

disp(['Choosen lambda = ', num2str(lambda,'%.e')])
disp(['best chi2 value = ' num2str(b_chi2value)])
disp(['Chi-squared misfit statistic = ',num2str(chi2_tot(:, ilambda))]);

% select the best model
m = m_tot{ilambda};
A = A_tot{ilambda};
G = G_tot{ilambda};

% evaluating model uncertainties
disp('Calculating pseudoinverse of A matrix..., please wait');
Ainv = pinv(full(A),1e-10);
disp('A matrix calculated.');
Cm = Ainv;                      % posterior covariance matrix
dCm = reshape(diag(Cm),nz,nx);
R = Ainv*G'*Wd*G;               % model resolution matrix
dR = reshape(diag(R),nz,nx);

figure()
plot(chi2_tot, R1D_tot,'o')
hold on
scatter(chi2_tot(ilambda), R1D_tot(ilambda), 200, 'ro')
axis equal
title('L-curve')
legend('L-curve', ['lambda = ' num2str(lambda, '%.e')])
xlabel('chi-square \chi^2')
ylabel('roughness R')

figure
subplot(2,1,1)
%inv = pcolor(xlog, ztop, m);
imagesc(xlog,ztop,m);
title('Inverted model')
subtitle(['\lambda = ', num2str(lambda, '%.e'), ',  P_G(m) = ', num2str(nperc), ' %'])
set(gca, 'YDir','reverse')
xlabel('Position [m]')
ylabel('Depth [m]')
ylim([0 5])
axis image
c = colorbar;
c.Label.String = '\sigma [S/m]';

subplot(2,1,2)
imagesc(xlog,ztop,log10(dR));
title('log10(Resolution)');
xlabel('Position [m]')
ylabel('Depth [m]')
axis image
colorbar

disp('code finished :')
toc
