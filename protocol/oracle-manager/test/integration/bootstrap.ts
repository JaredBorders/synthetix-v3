import { coreBootstrap } from '@synthetixio/hardhat-router/utils/tests';
import { ethers } from 'ethers';
import hre from 'hardhat';
import { NodeModule } from '../generated/typechain';
import NodeTypes from './mixins/Node.types';

const abi = ethers.utils.defaultAbiCoder;

interface Contracts {
  NodeModule: NodeModule;
}

const r = coreBootstrap<Contracts>();

const restoreSnapshot = r.createSnapshot();

export function bootstrap() {
  before(restoreSnapshot);
  return r;
}

export function bootstrapWithNodes() {
  const r = bootstrap();

  let aggregator: ethers.Contract;
  let aggregator2: ethers.Contract;
  let aggregator3: ethers.Contract;
  let aggregator4: ethers.Contract;

  let nodeId1: string;
  let nodeId2: string;
  let nodeId3: string;
  let nodeId4: string;

  before('deploy mock aggregator', async () => {
    const [owner] = r.getSigners();
    const factory = await hre.ethers.getContractFactory('AggregatorV3Mock');

    aggregator = await factory.connect(owner).deploy();
    await aggregator.mockSetCurrentPrice(ethers.utils.parseUnits('1', 6));

    aggregator3 = await factory.connect(owner).deploy();
    await aggregator3.mockSetCurrentPrice(ethers.utils.parseUnits('0.5', 6));

    aggregator2 = await factory.connect(owner).deploy();
    await aggregator2.mockSetCurrentPrice(ethers.utils.parseUnits('0.9', 6));

    aggregator4 = await factory.connect(owner).deploy();
    await aggregator4.mockSetCurrentPrice(ethers.utils.parseUnits('1.6', 6));
  });

  before('register leaf nodes', async function () {
    const NodeModule = r.getContract('NodeModule');

    const params1 = abi.encode(['address', 'uint256'], [aggregator.address, 0]);
    const params2 = abi.encode(['address', 'uint256'], [aggregator2.address, 0]);
    const params3 = abi.encode(['address', 'uint256'], [aggregator3.address, 0]);
    const params4 = abi.encode(['address', 'uint256'], [aggregator4.address, 0]);

    const registerNode = async (params: string) => {
      const tx = await NodeModule.registerNode(NodeTypes.CHAINLINK, params, []);
      await tx.wait();
      return await NodeModule.getNodeId(NodeTypes.CHAINLINK, params, []);
    };

    nodeId1 = await registerNode(params1);
    nodeId2 = await registerNode(params2);
    nodeId3 = await registerNode(params3);
    nodeId4 = await registerNode(params4);
  });

  return {
    ...r,
    nodeId1: () => nodeId1,
    nodeId2: () => nodeId2,
    nodeId3: () => nodeId3,
    nodeId4: () => nodeId4,
  };
}
