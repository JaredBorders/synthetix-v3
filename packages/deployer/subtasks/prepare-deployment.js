const fs = require('fs');
const path = require('path');
const mkdirp = require('mkdirp');
const { subtask } = require('hardhat/config');

const prompter = require('@synthetixio/core-js/utils/prompter');
const relativePath = require('@synthetixio/core-js/utils/relative-path');
const getDate = require('@synthetixio/core-js/utils/get-date');
const autosaveObject = require('../internal/autosave-object');
const { getDeploymentName, getAllDeploymentFiles } = require('../utils/deployments');
const { SUBTASK_PREPARE_DEPLOYMENT } = require('../task-names');

const DEPLOYMENT_SCHEMA = {
  properties: {
    completed: false,
    totalGasUsed: '0',
  },
  transactions: {},
  contracts: {},
};

subtask(
  SUBTASK_PREPARE_DEPLOYMENT,
  'Prepares the deployment file associated with the active deployment.'
).setAction(async (taskArguments, hre) => {
  const { instance, alias } = taskArguments;

  const deploymentsFolder = path.join(
    hre.config.deployer.paths.deployments,
    hre.network.name,
    instance
  );

  // Make sure the deployments folder exists
  await mkdirp(deploymentsFolder);

  const { previousFile, currentFile } = await _determineDeploymentFiles(deploymentsFolder, alias);

  hre.deployer.deployment = {
    file: currentFile,
    data: autosaveObject(currentFile, DEPLOYMENT_SCHEMA),
  };

  if (previousFile) {
    hre.deployer.previousDeployment = JSON.parse(fs.readFileSync(previousFile));
  }
});

/**
 * Initialize a new deployment file, or, if existant, try to continue using it.
 * @param {string} folder deployment folder where to find files
 * @param {string} [alias]
 * @returns {{
 *   currentName: string,
 *   currentFile: string,
 *   previousName: string
 *   previousFile: string
 * }}
 */
async function _determineDeploymentFiles(deploymentsFolder, alias) {
  const deployments = getAllDeploymentFiles({ folder: deploymentsFolder });
  const latestFile = deployments.length > 0 ? deployments[deployments.length - 1] : null;
  const latestName = getDeploymentName(latestFile);

  // Check if there is an unfinished deployment and prompt the user if we should
  // continue with it, instead of creating a new one.
  if (latestFile) {
    const latestData = JSON.parse(fs.readFileSync(latestFile));

    if (!latestData.properties.completed) {
      const use = await prompter.ask(
        `Do you wish to continue the unfinished deployment "${relativePath(latestFile)}"?`
      );

      const previousFile = deployments.length > 1 ? deployments[deployments.length - 2] : null;
      const previousName = getDeploymentName(previousFile);

      if (use) {
        return {
          currentName: latestName,
          currentFile: latestFile,
          previousName,
          previousFile,
        };
      }
    }
  }

  // Check that the given alias is available
  if (alias) {
    const exists = deployments.some((file) => file.endsWith(`-${alias}.json`));
    if (exists) {
      throw new Error(
        `The alias "${alias}" is already used by the deployment "${relativePath(exists)}"`
      );
    }
  }

  // Get the date with format `YYYY-mm-dd`
  const today = getDate();

  // Calculate the next deployment number based on the previous one
  let number = '00';
  if (latestName && latestName.startsWith(today)) {
    const previousNumber = latestName.slice(11, 13);
    number = `${Number.parseInt(previousNumber) + 1}`.padStart(2, '0');
  }

  const currentName = `${today}-${number}${alias ? `-${alias}` : ''}`;
  const currentFile = path.join(deploymentsFolder, `${currentName}.json`);

  return {
    currentName,
    currentFile,
    previousName: latestName,
    previousFile: latestFile,
  };
}
